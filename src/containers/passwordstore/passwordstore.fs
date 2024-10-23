\ passwordstore.fs
\ Legacy program to serve up passwords
\ By J. Stuart McMurray
\ Created 20241019
\ Last Modified 20241019

\ serr writes a line to stderr
: serr ( c-addr u - )  stderr write-line throw ; \ Write to stderr

\ Delete the password file.
s" passwords.fs" 2DUP
delete-file throw
s" Deleted password file " stderr write-file throw
( filename) serr

\ Serve password requests
1024 constant linelen
variable linebuf linelen 3 + chars allot

: crf  ( - ) cr stdout flush-file throw ; \ Newline and then flush stdout.
: .ps  ( - ) .s crf ;                     \ Print the stack and flush stdout.

\ eofdie terminates the program on EOF on stdin
: eofdie ( flag - )
        0= if
                ." EOF on stdin" crf
                ." done" crf
                2 (bye)
        then ;

\ readstdline reads a line into linebuf and leaves it on the stack
: readstdinline ( - c-addr u ) 
        linebuf linelen stdin read-line throw \ Get the line
        eofdie       \ Make sure we actually got a line
        linebuf swap \ Add the c-addr to the stack as well
;

\ serve is a REPL, more or less
: serve begin
        readstdinline           \ Read a line from stdin
        dup 0= if               \ Don't bother if we didn't get anything
                drop
        else
                try
                        evaluate crf    \ Call the word we got
                endtry-iferror
                        ." Exception: " . crf
                then
        then
        ." done" crf
again ;

\ Log that we're going.
s" Starting" serr
serve

\ Die if something really bad happens.
s" An unknown terrible thing happened" serr 3 (bye)

\ vim: ft=forth:si
