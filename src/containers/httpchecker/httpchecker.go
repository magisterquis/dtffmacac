// Program httpchecker is a little webserver which checks if an HTTP server
// is listening.  It is meant to demonstrate shell injection.
package main

/*
 * httpchecker.go
 * Webserver which checks for listening HTTP
 * By J. Stuart McMurray
 * Created 20241009
 * Last Modified 20241020
 */

import (
	"flag"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/magisterquis/curlrevshell/lib/sstls"
)

const (
	// targetParam is the URL parameter to specify the target to test.
	targetParam = "target"
	// urlPath is the URL path we serve
	urlPath = "/check"
)

// tmpl is the template which renders our HTML.
var tmpl = template.Must(template.New("page").Parse(`<!doctype html>
<html>
<head>
<title>HTTP Checker</title>
</body>
<h1>HTTP Checker</h1>
<form action=` + urlPath + `>
	<label for="target">Target:</label>
	<input type="text" size="64" id="target" name="` + targetParam + `"><br>
</form>
{{- if .Target }}
<h2>Target</h2>
<pre>
{{ .Target }}
</pre>
{{ end }}
{{- if .Command }}
<h2>Command</h2>
<pre>
{{ .Command }}
</pre>
{{ end }}
{{- if .Output }}
<h2>Output</h2>
<pre>
{{ .Output }}
</pre>
{{ end }}
{{- if .Error }}
<h2>Error</h2>
<pre>
{{ .Error }}
</pre>
{{ end }}
</body>
</html>
`))

// scanResult is what we got when we scanned something.
type scanResult struct {
	Target  string
	Command string
	Output  string
	Error   string
}

func main() {
	var (
		lAddr = flag.String(
			"listen",
			"0.0.0.0:4444",
			"HTTP listen `address`",
		)
		baCreds = flag.String(
			"credentials",
			"",
			"Basic auth `username:password`",
		)
	)
	flag.Usage = func() {
		fmt.Fprintf(
			os.Stderr,
			`Usage: %s [options]

Serves up a webpage which makes it easy to check if a port is serving HTTP.
Wraps curl under the hood.

Options:
`,
			filepath.Base(os.Args[0]),
		)
		flag.PrintDefaults()
	}
	flag.Parse()

	/* Work out the basic auth creds. */
	u, p, ok := strings.Cut(*baCreds, ":")
	if !ok {
		log.Fatalf(
			"Basic auth credentials must be a " +
				"username:password pair",
		)
	}

	/* Listen on the network. */
	l, err := sstls.Listen("tcp", *lAddr, "", 0, "")
	if nil != err {
		log.Fatalf("Error listening on %s: %s", *lAddr, err)
	}
	log.Printf(
		"Listening for HTTPS requests on %s with fingerprint %s",
		l.Addr(),
		l.Fingerprint,
	)

	/* Serve HTTP requests. */
	http.Handle(urlPath, AuthedHandler{
		Username: u,
		Password: p,
	})
	log.Fatalf("HTTP Server error: %s", http.Serve(l, nil))
}

// AuthedHandler checks basic auth creds before allowing anything to happen.
type AuthedHandler struct {
	Username string
	Password string
}

// ServeHTTP handles a request for a check.
func (ah AuthedHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	/* Make sure we have the right creds. */
	if u, p, ok := r.BasicAuth(); !ok ||
		u != ah.Username || p != ah.Password {
		w.Header().Set("WWW-Authenticate", `Basic realm="restricted"`)
		http.Error(
			w,
			http.StatusText(http.StatusUnauthorized),
			http.StatusUnauthorized,
		)
		return
	}

	/* Scan a target if we have one. */
	var res scanResult
	if res.Target = r.FormValue(targetParam); "" != res.Target {
		log.Printf("[%s] Checking %s", r.RemoteAddr, res.Target)
		res.Command = fmt.Sprintf("curl -skm3 '%s'", res.Target)
		o, err := exec.Command(
			"/bin/sh",
			"-c", res.Command,
		).CombinedOutput()
		res.Output = string(o)
		if nil != err {
			res.Error = err.Error()
		}
	}
	/* Send back the page. */
	if err := tmpl.Execute(w, res); nil != err {
		log.Printf(
			"[%s] Error executing template: %s",
			r.RemoteAddr,
			err,
		)
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}
