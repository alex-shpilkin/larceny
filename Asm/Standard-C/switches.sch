; Copyright 1998 Lars T Hansen.
;
; $Id: switches.sch,v 1.1.1.1 1998/11/19 21:52:02 lth Exp $
; switches -- Switches for the standard-C assembler

(define unsafe-code
  (make-twobit-flag 'unsafe-code))

(define catch-undefined-globals
  (make-twobit-flag 'catch-undefined-globals))

(define inline-allocation
  (make-twobit-flag 'inline-allocation))
  
(define inline-assignment
  (make-twobit-flag 'inline-assignment))

(define (peephole-optimization . rest) #f)

(define (single-stepping . rest) #f)

(define (display-assembler-flags)
  (display "Standard-C Assembler flags") (newline)
  (display-twobit-flag unsafe-code)
  (display-twobit-flag catch-undefined-globals)
  (display-twobit-flag inline-allocation)
  (display-twobit-flag inline-assignment)
  (display-twobit-flag peephole-optimization))

(define (set-assembler-flags! mode)
  (inline-allocation #f)
  (inline-assignment #f)
  (catch-undefined-globals #t)
  (peephole-optimization #f)
  (unsafe-code #f))

(set-assembler-flags! 'default)

; eof
