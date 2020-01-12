(defpackage #:other
  (:use :cl :utility))
(in-package :other)

;;;;************************************************************************;;;;
;;;;<BRUSH>

(defun player-feet-at (&rest rest)
  (declare (ignorable rest))
  (multiple-value-bind (x y z) (player-feet)
    ;;(print (list x y z))
    (dobox ((x (+ x -1) (+ x 2))
	    (z (+ z -1) (+ z 2)))
	   (setf (b@ x y z) (nick :grass)))))

(defun line (px py pz &optional
			(vx *x*)
			(vy *y*)
			(vz *z*)
	       (blockid *blockid*)
	       (aabb *fist-aabb*))
  (aabbcc::aabb-collect-blocks ((+ 0.5 px)
				(+ 0.5 py)
				(+ 0.5 pz)
				(- vx px)
				(- vy py)
				(- vz pz)
				aabb)
      (x y z dummy)
    (declare (ignore dummy))
    (when (b= (nick :air) (b@ x y z))
      (sandbox::plain-setblock x y z blockid))))

(defun degree-to-rad (&optional (n (random 360)))
  (* n (load-time-value (floatify (/ pi 180)))))
(defun rotate-normal (&optional
			(x (degree-to-rad))
			(y (degree-to-rad))
			(z (degree-to-rad)))
  (sb-cga:transform-point
   (sb-cga::vec 1.0 0.0 0.0)
   (sb-cga::rotate* x y z)))
(defun vec-values (&optional (vec (sb-cga::vec 1.0 2.0 3.0)))
  (with-vec (x y z) (vec)
    (values x y z)))
;;
(defun tree (&optional (x *x*) (y *y*) (z *z*) (minfactor 6.0))
  (labels ((rec (place minfactor)
	     (when (>= minfactor 0)
	       (dotimes (x (random 5))
		 (let ((random-direction (sb-cga::vec* (rotate-normal) (expt 1.5 minfactor))))
		   (let ((new (sb-cga::vec+ place random-direction)))
		     (multiple-value-call
			 'line
		       (vec-values place)
		       (vec-values new)
		       (if (>= 4 minfactor)
			   (nick :leaves)
			   (nick :log))
		       (create-aabb (* 0.1 minfactor)))
		     (rec new (1- minfactor))))))))
    (rec (multiple-value-call 'sb-cga::vec (floatify2 x y z))
	 minfactor)))
(defun floatify2 (&rest values)
  (apply 'values (mapcar 'floatify values)))
;;

(defun line-to-player-feet (&rest rest)
  (declare (ignorable rest))
  (multiple-value-bind (x y z) (player-feet)
    ;;(print (list x y z))
    (line x
	  y
	  z
	  *x*
	  *y*
	  *z*
	  (nick :glass;:planks
		))))
(defun get-chunk (x y z)
  (multiple-value-bind (x y z) (world::chunk-coordinates-from-block-coordinates x y z)
    ;;FIXME::use actual chunk dimensions, not magic number 16
    (values (* x 16)
	    (* y 16)
	    (* z 16))))
(defun background-generation (key)
  (let ((job-key (cons :world-gen key)))
    (sucle-mp::submit-unique-task
     job-key
     ((lambda ()
	(generate-for-new-chunk key))
      :callback (lambda (job-task)
		  (declare (ignore job-task))
		  (sandbox::dirty-push-around key)
		  (sucle-mp::remove-unique-task-key job-key))))))

(utility:with-unsafe-speed
  (defun generate-for-new-chunk (key)
    (multiple-value-bind (x y z) (world::unhashfunc key)
      (declare (type fixnum x y z))
      ;;(print (list x y z))
      (when (>= y -1)
	(dobox ((x0 x (the fixnum (+ x 16)))
		(y0 y (the fixnum (+ y 16)))
		(z0 z (the fixnum (+ z 16))))
	       (let ((block (let ((threshold (/ y 512.0)))
			      (if (> threshold (black-tie::perlin-noise-single-float
						(* x0 0.05)
						(+ (* 1.0 (sin y0)) (* y0 0.05))
						(* z0 0.05)))
				  0
				  1))))
		 (setf (world::getobj x0 y0 z0)
		       (world::blockify block
					(case block
					  (0 15)
					  (1 0))
					0))))))))

(defun 5fun (x y z)
  (multiple-value-bind (x y z) (get-chunk x y z)
    (dobox ((0x (- x 16) (+ x 32) :inc 16)
	    (0y (- y 16) (+ y 32) :inc 16)
	    (0z (- z 16) (+ z 32) :inc 16))
	   (background-generation (multiple-value-call
				      'world::create-chunk-key
				    (world::chunk-coordinates-from-block-coordinates 
				     0x
				     0y
				     0z))))))

(defun 5fun (x y z)
  (loop :repeat 10 :do
     (let ((newx x)
	   (newy y)
	   (newz z))
       (progn
	 (let ((random (random 3))
	       (random2 (- (* 2 (random 2)) 1)))
	   (case random
	     (0 (incf newx (* random2 3)))
	     (1 (incf newy (* random2 3)))
	     (2 (incf newz (* random2 3)))))
	 (line
	  x y z
	  newx newy newz
	  (nick :gravel))
	 (setf x newx
	       y newy
	       z newz)))))

(defun 5fun (x y z)
  ;;put a layer of grass on things
  (around (lambda (x y z)
	    (when (and (b= (nick :air) (b@ x y z))
		       (not (b= (nick :air) (b@ x (1- y) z)))
		       (not (b= (nick :grass) (b@ x (1- y) z))))
	      (setf (b@ x y z) (nick :grass))))
	  x y z))

(defun around (fun x y z)
  (let ((radius 5))
    (dobox ((0x (- x radius) (+ x radius 1))
	    (0y (- y radius) (+ y radius 1))
	    (0z (- z radius) (+ z radius 1)))
	   (funcall fun 0x 0y 0z))))

;;;;</BRUSH>
;;;;************************************************************************;;;;
