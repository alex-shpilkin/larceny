; Testsuite/Lib/fib.sch
; Fibonacci test
;
; $Id: fib.sch,v 1.1.1.1 1998/11/19 21:52:33 lth Exp $
;
; Tests non-tail calls; fixnum comparison; fixnum arithmetic.

(define (run-fib-tests)
  (allof "fibonacci tests"
	 (test "(fib 1)" (fib 1) 1)
	 (test "(fib 10)" (fib 10) 55)
	 (test "(fib 20)" (fib 20) 6765)
	 (test "(fib 30)" (fib 30) 832040)))

(define (fib n)
  (if (< n 2)
      n
      (+ (fib (- n 1)) (fib (- n 2)))))

; eof
