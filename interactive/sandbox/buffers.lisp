(defpackage #:aplayground
  (:use 
   #:cl
   #:fuktard))

(in-package :aplayground)

(defun fill-with-flhats (array)
  (map-into array #'flhat:make-flhat))
(defun make-iterators (buffer result)
  (map-into result (lambda (x) (flhat:make-flhat-iterator x)) buffer))
(defun reset-attrib-buffer-iterators (fill-data)
  (dotimes (x (array-total-size fill-data))
    (flhat:reset-iterator (aref fill-data x))))

(defparameter *attrib-buffers* (fill-with-flhats (make-array 16 :element-type t :initial-element nil)))
(defparameter *attrib-buffer-iterators*
  (make-iterators *attrib-buffers* (make-array 16 :element-type t :initial-element nil)))

(defmacro with-iterators ((&rest bufvars) buf func &body body)
  (let* ((syms (mapcar (lambda (x) (declare (ignorable x)) (gensym)) bufvars)))
    (with-vec-params
	syms `(,buf)
	(let ((acc (cons 'progn body)))
	  (dolist (sym syms) 
	    (setf acc (list func
			    (pop bufvars) sym acc)))
	  acc))))

#+nil
(defparameter *attrib-buffer-fill-pointer*
  (tally-buffer *attrib-buffer-iterators* (make-attrib-buffer-data)))

#+nil
((defun tally-buffer (iterator-buffer result)
   (map-into result (lambda (x) (iterator-count x)) iterator-buffer))
 (defun iterator-count (iterator)
   (if (iter-ator:p-array iterator)
       (1+ (flhat:iterator-position iterator))
       0)))

#+nil
((defparameter *buffer-vector-scratch* (make-array 16))
 (defun get-buf-param (iter attrib-order &optional (newarray *buffer-vector-scratch*))
   (let ((len (length attrib-order)))
     (dotimes (x len)
       (setf (aref newarray x)
	     (aref iter (aref attrib-order x)))))
   newarray))


