; -*- Scheme -*-
;
; Multi-lingual autoconfiguration program, version 2.
; Viciously hacked to accomodate v0.20, needs cleaning up. It's a mess.
; ASM parts are SPARC dependent (sigh).
;
; USAGE
;   (config <configfile> ...)
;
; DESCRIPTION
;   The situation is this: we have a number of defined constants which are
;   used in various guises and with slightly differing names in several
;   programs in different languages. For example, there is the constant
;   "M_BREAK", which is the index in the millicode table of the entry point
;   for the breakpoint handler. In C, this identifier denotes the value
;   "x", while in assembly language it denotes the value "x*4" and in
;   scheme it denotes "x*4" also but here it has the name "$m.break".
;
;   The problem is to maintain "header" files in all languages and ensure that
;   they are in sync. The only reasonable way of doing this is to generate
;   the language specific headers automatically from one language independent
;   base file.
;
;   While we could have used M4, Scheme is more fun. Hence this program.
;
;   There is one config file for each group of related header files.
;   The first expression in the file should define the output files:
;
;     (define-files <c header> <assy header> <scheme header>)
;
;   A file name can be #f, meaning that language will not be generated from
;   this config file at all.
;
;   Then the constants follow. The basic syntax of each constant is this:
; 
;     (define-const <name> <base value> <c name> <assy name> <scheme name>)
;
;   The <x name> in the define-const can be #f, avoiding generating it 
;   altogether for the appropriate language. If the entry is not #f but the
;   file entry was #f, the entry is ignored.
;
;   This defines the base value and the names for the header files for all
;   languages. The base value can be any constant or it can be a previously
;   defined <name>, or a general Scheme expression involving previously 
;   defined <name>s and Scheme procedures. If the base value is not simply
;   a constant, known variables will be substituted for and the resulting
;   expression will be passed to "eval".
;
;   After evaluation, a the base value is passed through an action procedure
;   for each language; this procedure may modify the value and return the
;   modified value. The default action is the identity procedure.
;
;   One can override the default action on a language basis:
;
;     (define-action <language> <expr>)
;
;   where <language> is one of the symbols "c", "assembly", or "scheme", and
;   where <expr> must evaluate to a procedure of one argument. It will be
;   invoked with the base value of the define-const if the entry for the
;   language is non-false. <Expr> is evaluated like the base: known variables
;   are substituted for before evaluation.
;
; AUTHOR
;   Lars Thomas Hansen
;
; BUGS
;   Some more shorthands would be nice.
;
;   Little, if any, error checking. Watch where you step.
;
;   The evaluator knows nothing of quasiquotations; don't use them. Also, don't
;   use a defined name as a formal in a lambda expression, and don't define
;   a name using a Scheme reserved word.


; "Config" takes configuration files as arguments and runs through each one
; in turn.

(define (config . argv)

  (define $format
    (case host
      ((chez)   (lambda (port . rest) (display (apply format rest) port)))
      ((larceny) (lambda (port . rest) (apply format port rest)))
      (else ???)))

  (define $gensym
    (case host
      ((chez)  gensym)
      ((larceny)  (lambda () (gensym "G")))
      (else ???)))

  (define error-cont #f)

  (define table-objects '())
  (define table-counter 0)

  (define (conf-error kill? msg . rest)
    (apply $format (current-output-port) (cons msg rest))
    (newline)
    (if kill?
	(error-cont #f)))

  (define (caddddr x) (car (cddddr x)))
  (define (cadddddr x) (car (cdr (cddddr x))))

  ; format strings for the three languages

  (define formats
    '("#define ~a ~a~%"
       "#define ~a ~a~%"
       "(define ~a ~a)~%"))

  ; comment header strings for the three languages

  (define comments
    '("/* DO NOT EDIT THIS FILE. Edit the config file and rerun \"config\". */"
      "! DO NOT EDIT THIS FILE. Edit the config file and rerun \"config\"."
      "; DO NOT EDIT THIS FILE. Edit the config file and rerun \"config\"."))

  ; return a config vector: each element corresponds to a language and has
  ; a file name, a port, and a default, or is altogether #f. There is also
  ; the first element, which is a list of defined names and associated
  ; base values.

  (define id (lambda (x) x))

  (define (open-output-files flist)
    (list->vector (cons '()
			(map (lambda (x y z)
			       (if x
				   (begin (delete-file x)
					  (let ((f (open-output-file x)))
					    (display z f)
					    (newline f)
					    (newline f)
					    (make-lang x f y id)))
				   #f))
			     flist
			     formats
			     comments))))

  ; The "info" vector has four fields. The first is the symbol table of
  ; previously defined fields. The next are language entries for C, Assembly,
  ; and Scheme.

  (define make-info vector)
  (define (info.symtab x) (vector-ref x 0))
  (define (info.symtab! x v) (vector-set! x 0 v))
  (define (info.c x) (vector-ref x 1))
  (define (info.c! x v) (vector-set! x 1 v))
  (define (info.assy x) (vector-ref x 2))
  (define (info.assy! x v) (vector-set! x 2 v))
  (define (info.sch x) (vector-ref x 3))
  (define (info.sch! x v) (vector-set! x 3 v))

  (define (info.lookup x n)
    (assq n (info.symtab x)))

  ; The "Language" vector has four fields: file name, port, format string, and
  ; action. 

  (define make-lang vector)
  (define (lang.fn x)  (vector-ref x 0))
  (define (lang.port x) (vector-ref x 1))
  (define (lang.fmt x) (vector-ref x 2))
  (define (lang.action x) (vector-ref x 3))

  ; predicates for commands

  (define (define-files? x)
    (and (pair? x) (eq? (car x) 'define-files)))

  (define (define-const? x)
    (and (pair? x) (eq? (car x) 'define-const)))

  (define (define-action? x)
    (and (pair? x) (eq? (car x) 'define-action)))

  (define (define-table? x)
    (and (pair? x) (eq? (car x) 'define-table)))

  (define (start-roots? x)
    (and (pair? x) (eq? (car x) 'start-roots)))

  (define (end-roots? x)
    (and (pair? x) (eq? (car x) 'end-roots)))

  (define (define-global? x)
    (and (pair? x) (eq? (car x) 'define-global)))

  (define (define-mproc? x)
    (and (pair? x) (eq? (car x) 'define-mproc)))

  (define (align? x)
    (and (pair? x) (eq? (car x) 'align)))

  (define (config-loop inp info)
    (let loop ((item (read inp)) (info info))
      (cond ((eof-object? item)
	     #t)
	    ((define-const? item)
	     (loop (read inp) (define-const item info)))
	    ((define-action? item)
	     (loop (read inp) (define-action item info)))
	    ((define-table? item)
	     (define-table item)
	     (loop (read inp) info))
	    ((start-roots? item)
	     (loop (read inp) (define-const `(define-const
						  first-root
						  ,table-counter
						  "FIRST_ROOT" #f #f)
				info)))
	    ((end-roots? item)
	     (loop (read inp) (define-const `(define-const
						  last-root
						  ,(- table-counter 1)
						  "LAST_ROOT" #f #f)
				info)))
	    ((define-global? item)
	     (table-word 0 (or (cadr item) (caddr item) (cadddr item) "???"))
	     (let ((i (define-const (cons 'define-const
					     (cons ($gensym)
						   (cons table-counter
							 (cdr item))))
			info)))
	       (set! table-counter (+ table-counter 1))
	       (loop (read inp) i)))
	    ((define-mproc? item)
	     (table-branch (extname (list-ref item 4)))
	     (let ((i (define-const (cons 'define-const
					     (cons ($gensym)
						   (cons table-counter
							 (cdr item))))
			info)))
	       (set! table-counter (+ table-counter 2))
	       (loop (read inp) i)))
	    ((align? item)
	     (let ((n (cadr item)))
	       (if (< n table-counter)
		   (error 'config "Align directive exceeded:" item)
		   (let loop2 ()
		     (if (< table-counter n)
			 (begin (table-word 0 #f)
				(set! table-counter (+ table-counter 1))
				(loop2))
			 (loop (read inp) info))))))
	    (else
	     (conf-error #f "Unknown command ~a" item)
	     (loop (read inp) info)))))

  (define (define-table item)

    (define (the-table port delegate)
      (lambda (op)
	(case op
	  ((close) (lambda () (close-output-port port)))
	  (else (delegate port op)))))

    (define (open-table-output name table comment)
      (delete-file name)
      (let ((port (open-output-file name)))
	(display comment port)
	(newline port)
	(set! table-objects (cons (the-table port table) table-objects))))

    (let ((c-name (cadr item))
	  (asm-name (caddr item)))
      (if c-name
	  (open-table-output c-name standard-C-table (car comments)))
      (if asm-name
	  (open-table-output asm-name SPARC-table (cadr comments)))
      (table-heading)
      (set! table-counter 0)
      #t))

  (define (table-heading)
    (for-each (lambda (t)
		((t 'heading)))
	      table-objects))

  (define (table-word value comment)
    (for-each (lambda (t)
		((t 'word) value comment))
	      table-objects))

  (define (table-branch name)
    (for-each (lambda (t)
		((t 'branch) name))
	      table-objects))

  (define (table-footer)
    (for-each (lambda (t)
		((t 'footer)))
	      table-objects))

  ; Evaluate expression, watching out for constants.

  (define (eval-expr expr symtab)

    (define (subs expr)
      (cond ((number? expr) expr)
	    ((symbol? expr)
	     (let ((probe (assq expr symtab)))
	       (if probe
		   (cdr probe)
		   expr)))
	    ((string? expr) expr)
	    ((boolean? expr) expr)
	    ((null? expr) expr)
	    ((pair? expr)
	     (if (eq? 'quote (car expr))
		 expr
		 (map subs expr)))
	    (else
	     (conf-error #t "Invalid expression ~a" expr))))

    (if (number? expr) 
	expr
	(eval (subs expr))))

  ; Define a constant; return a new info structure.

  (define (define-const x info)

    (define (dump-const! entry lang base)
      (if lang
	  (if (string? entry)
	      ($format (lang.port lang)
		       (lang.fmt lang)
		       entry
		       ((lang.action lang) base))
	      #f)
	  #f))

    (let ((name (cadr x))
	  (base (eval-expr (caddr x) (info.symtab info)))
	  (c    (cadddr x))
	  (assy (caddddr x))
	  (sch  (cadddddr x)))
      (let ((probe (info.lookup info name)))
	(if probe
	    (begin 
	      (conf-error #f "Redefinition of ~a ignored." name)
	      info)
	    (begin
	      (dump-const! c (info.c info) base)
	      (dump-const! assy (info.assy info) base)
	      (dump-const! sch (info.sch info) base)
	      (make-info (cons (cons name base) (info.symtab info))
			 (info.c info)
			 (info.assy info)
			 (info.sch info)))))))

  ; Create a new action for a language; return the new info structure.

  (define (define-action x info)

    (define (new-lang lang act)
      (if (not lang)
	  lang
	  (make-lang (lang.fn lang) (lang.port lang) (lang.fmt lang) act)))

    (let ((lang (cadr x))
	  (expr (eval-expr (caddr x) (info.symtab info))))
      (make-info (info.symtab info)
		 (if (eq? lang 'c)
		     (if (info.c info) 
			 (new-lang (info.c info) expr)
			 #f)
		     (info.c info))
		 (if (eq? lang 'assembly)
		     (if (info.assy info) 
			 (new-lang (info.assy info) expr)
			 #f)
		     (info.assy info))
		 (if (eq? lang 'scheme)
		     (if (info.sch info)
			 (new-lang (info.sch info) expr)
			 #f)
		     (info.sch info)))))

  ; Main program for running configure on a file.

  (define (run-configure fn)
    (call-with-current-continuation
     (lambda (k)
       (set! error-cont k)
       (let* ((inp   (open-input-file fn))
	      (files (read inp)))
	 (if (not (define-files? files))
	     (conf-error #t "Expected 'define-files' in ~a" fn))
	 (let ((config-info (open-output-files (cdr files))))
	   (config-loop inp config-info)
	   (close-input-port inp)
	   (close-output-files config-info))))))

  (define (close-output-files info)
    (if (info.c info) (close-output-port (lang.port (info.c info))))
    (if (info.assy info) (close-output-port (lang.port (info.assy info))))
    (if (info.sch info) (close-output-port (lang.port (info.sch info))))
    (table-footer)
    (for-each (lambda (t)
		((t 'close)))
	      table-objects))

  ;; SPARC table

  (define (sparc-table output op)

    (define (show data)
      (for-each (lambda (x)
		  (display x output))
		data))

    (define (table-heading)
      (show '("#include \"asmmacro.h\"" #\newline
	      #\tab ".seg" #\tab "\"data\"" #\newline
	      #\tab ".global EXTNAME(globals)" #\newline
	      #\tab ".align 8" #\newline
	      "EXTNAME(globals):" #\newline)))

    (define (table-word value comment)
      (show `(#\tab ".word" #\tab ,value #\tab "! "
		    ,(or comment "padding")
		    #\newline)))

    (define (table-branch name)
      (show `(#\tab "b" #\tab ,name #\newline #\tab "nop" #\newline)))

    (define (table-footer) #f)

    (case op
      ((heading) table-heading)
      ((word) table-word)
      ((branch) table-branch)
      ((footer) table-footer)
      (else ???)))

  ;; Standard-C table

  (define (standard-C-table output op)

    (define (show data)
      (for-each (lambda (x)
		  (display x output))
		data))

    (define (table-heading)
      (show '("#include \"larceny-types.h\"" #\newline
	      "word globals[] = {" #\newline)))

    (define (table-word value comment)
      (if comment
	  (show `(#\tab ,value "," #\tab "/* " ,comment " */" #\newline))))

    (define (table-branch name) #t)

    (define (table-footer)
      (show '("};" #\newline)))

    (case op
      ((heading) table-heading)
      ((word) table-word)
      ((branch) table-branch)
      ((footer) table-footer)
      (else ???)))


  (for-each run-configure argv))

(define (extname str)
  (string-append "EXTNAME(" str ")"))

; eof
