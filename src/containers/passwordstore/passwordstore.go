// Program passwordstore wraps an old Forth password store.
package main

/*
 * passwordstore.go
 * TLS-wrap an old password store
 * By J. Stuart McMurray
 * Created 20241019
 * Last Modified 20241021
 */

import (
	"bufio"
	"bytes"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/magisterquis/curlrevshell/lib/sstls"
)

// PasswordRequestTimeout is how long we wait when asking Forth for a password.
const PasswordRequestTimeout = time.Second

func main() {
	var (
		lAddr = flag.String(
			"https-listen",
			"0.0.0.0:5555",
			"HTTPS listen `address`",
		)
		fAddr = flag.String(
			"forth-listen",
			"127.0.0.1:9999",
			"Forth listen `address`",
		)
		fWait = flag.Duration(
			"forth-wait",
			10*time.Second,
			"Forth connect `wait`",
		)
		fpFile = flag.String(
			"fingerprint",
			"tls_fingerprint",
			"TLS fingerprint `file`",
		)
		pFile = flag.String(
			"client_password",
			"passwordstore_password",
			"Required HTTPS client `password`",
		)
	)
	flag.Usage = func() {
		fmt.Fprintf(
			os.Stderr,
			`Usage: %s [options]

Listens for and wraps the old Forth password store, which must connect within
-forth-wait.  Stdout will be closed when the listener's ready.

Serves HTTPS requests, which must have basic auth with the password in
the -password file and the secret name as the path.

The TLS fingerprint will be written to a file (-fingerprint).

Somewhat fragile.

Options:
`,
			os.Args[0],
		)
		flag.PrintDefaults()
	}
	flag.Parse()

	log.Printf("Starting")

	/* Get the HTTPS Password. */
	b, err := os.ReadFile(*pFile)
	if nil != err {
		log.Fatalf("Error reading password from %s", *pFile)
	}
	password := strings.TrimRight(string(b), "\n")
	if err := os.Remove(*pFile); nil != err {
		log.Fatalf("Error removing password file %s: %s", *pFile, err)
	}

	/* Listener for Forth. */
	ta, err := net.ResolveTCPAddr("tcp", *fAddr)
	if nil != err {
		log.Fatalf(
			"Error resolving Forth listen address %s: %s",
			*fAddr,
			err,
		)
	}
	fl, err := net.ListenTCP("tcp", ta)
	if nil != err {
		log.Fatalf("Error listening for Forth on %s: %s", ta, err)
	}
	log.Printf("Listening for connection from Forth on %s", fl.Addr())
	if err := os.Stdout.Close(); nil != err {
		log.Fatalf("Error closing stdout: %s", err)
	}
	fl.SetDeadline(time.Now().Add(*fWait))
	store, err := fl.Accept()
	if nil != err {
		log.Fatalf("Error accepting Forth connection: %s", err)
	}
	log.Printf("Forth connected from %s", store.RemoteAddr())
	if err := fl.Close(); nil != err {
		log.Fatalf("Error closing Forth listener: %s", err)
	}

	/* Read from the store and make the lines available. */
	passwordCh := make(chan string, 1024)
	go readFromStore(passwordCh, store)

	/* Listen for HTTP clients. */
	l, err := sstls.Listen("tcp", *lAddr, "", 0, "")
	if nil != err {
		log.Fatalf(
			"Error starting TLS listener on %s: %s",
			*lAddr,
			err,
		)
	}
	log.Printf("Listening on %s", l.Addr())

	/* Save our fingerprint for later use. */
	if err := os.WriteFile(
		*fpFile,
		[]byte(l.Fingerprint+"\n"),
		0644,
	); nil != err {
		log.Fatalf("Error writing fingerprint to %s: %s", *fpFile, err)
	}
	log.Printf("Wrote fingerprint %s to %s", l.Fingerprint, *fpFile)

	/* Handle clients. */
	var storeMu sync.Mutex
	http.HandleFunc("/{name}", func(
		w http.ResponseWriter,
		r *http.Request,
	) {
		name := r.PathValue("name")

		/* Connection-specific logger.  Could have used slog, but eh. */
		l := func(f string, v ...any) {
			log.Printf(
				"[%s - %s] %s",
				r.RemoteAddr,
				name,
				fmt.Sprintf(f, v...),
			)
		}

		/* Make sure we get the right auth. */
		if _, p, ok := r.BasicAuth(); !ok || password != p {
			if "" == p {
				l("Missing auth")
			} else {
				l("Incorrect auth: %s", p)
			}
			sc := http.StatusUnauthorized
			http.Error(w, http.StatusText(sc), sc)
			return
		}

		/* Ask for the password. */
		storeMu.Lock()
		defer storeMu.Unlock()
		if err := store.SetWriteDeadline(
			time.Now().Add(PasswordRequestTimeout),
		); nil != err {
			l("Error setting password request deadline: %s", err)
			os.Exit(2)
		}
		if _, err := fmt.Fprintf(store, "%s\n", name); nil != err {
			http.Error(
				w,
				fmt.Sprintf("Error: %s", err),
				http.StatusInternalServerError,
			)
			l("Error requesting password for %s: %s", name, err)
			os.Exit(3)
		}

		/* Make sure we get the right sort of things back. */
		buf := new(bytes.Buffer)
		lines := 0
		for l := range passwordCh {
			/* If we've got all we're getting, we're good. */
			if "done" == l {
				break
			} else if "" == l {
				continue
			}
			/* Save this line to return. */
			lines++
			fmt.Fprintf(buf, "%s\n", l)
		}
		switch lines {
		case 0: /* Didn't get anything :( */
			l("Got nothing")
			http.Error(
				w,
				"Got nothing",
				http.StatusInternalServerError,
			)
		case 1: /* Good. */
			l("Retrieved password")
			buf.WriteTo(w)
		default: /* Error or something. */
			l("Error")
			w.WriteHeader(http.StatusBadRequest)
			buf.WriteTo(w)
		}
	})

	log.Printf("Starting HTTPS service on %s", l.Addr())
	log.Fatalf("HTTPS Error: %s", http.Serve(l, nil))
}

// readFromStore reads lines from store and sends them to ch.  It terminates
// the program on error.
func readFromStore(ch chan<- string, store io.Reader) {
	scanner := bufio.NewScanner(store)
	for scanner.Scan() {
		log.Printf("Got line from Forth: %q", scanner.Text())
		ch <- scanner.Text()
	}
	if err := scanner.Err(); nil != err {
		log.Fatalf("Connection to Forth died with error: %s", err)
	}
	log.Fatalf("Connection to Forth died peacefully")
}
