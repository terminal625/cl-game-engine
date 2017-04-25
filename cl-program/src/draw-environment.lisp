(in-package :sandbox)


(defparameter vsync? t)

(defparameter *mat4-identity* (cg-matrix:identity-matrix))

(defconstant +single-float-just-less-than-one+ 0.99999997)

(defparameter *16x16-tilemap* (regular-enumeration 16 16))
(defparameter *4x4-tilemap* (regular-enumeration 4 4))

(defparameter *screen-scaled-matrix* (cg-matrix:identity-matrix))

(defparameter *attrib-buffers* (fill-with-flhats (make-attrib-buffer-data)))
(defparameter *attrib-buffer-iterators*
  (make-iterators *attrib-buffers* (make-attrib-buffer-data)))
(defparameter *attrib-buffer-fill-pointer*
  (tally-buffer *attrib-buffer-iterators* (make-attrib-buffer-data)))

(defun make-eq-hash ()
  (make-hash-table :test (quote eq)))

(defparameter *backup* (make-eq-hash))
(defparameter *stuff* (make-eq-hash))

(defparameter *default-tex-params* (quote ((:texture-min-filter . :nearest)
					   (:texture-mag-filter . :nearest)
					   (:texture-wrap-s . :repeat)
					   (:texture-wrap-t . :repeat))))

(defparameter *postex* (quote (("POS" . 0)	
			       ("TEX" . 8)
			       ("FGCOL" . 9)
			       ("BGCOL" . 10)
			       )))

(defparameter *postexcol* (quote (("POS" . 0)	
				  ("TEX" . 8)
				  ("COL" . 9))))

(defparameter *clear-display-buffer* t)

(defun render ()
  (if vsync?
      (window::set-vsync t)
      (window::set-vsync nil))
  (draw-things)

  (window:update-display))

(defparameter *one-over-window-width* 0.0)
(defparameter *one-over-window-height* 0.0)


(defun draw-things ()
  (gl:disable :depth-test :blend)
  (gl:depth-mask :false)
  (gl:depth-func :always)
  (gl:disable :cull-face)
  (gl:clear-color 0.0 (/ 8.0 256.0) (/ 16.0 256.0) 0f0)
  (when *clear-display-buffer*
    (gl:clear :color-buffer-bit))

  (setf *one-over-window-width* (/ 1.0 e:*width*)
	*one-over-window-height* (/ 1.0 e:*height*))
  (cg-matrix:%scale* *screen-scaled-matrix*
		     *one-over-window-width*
		     *one-over-window-height*
		     1.0) 
  (gl:viewport 0 0 e:*width* e:*height*)

  (let* ((solidshader (get-stuff :textshader *stuff* *backup*))
	 (solidshader-uniforms (glget solidshader :program))
	 (pmv (getuniform solidshader-uniforms :pmv)))
    (gl:use-program solidshader)
    (gl:bind-texture :texture-2d (get-stuff :font *stuff* *backup*))
    (draw-text-layers pmv))

  (let* ((simpleshader (get-stuff :simpleshader *stuff* *backup*))
	 (simpleshader-uniforms (glget simpleshader :program))
	 (pmv (getuniform simpleshader-uniforms :pmv)))
    (gl:use-program simpleshader)
    (gl:bind-texture :texture-2d (get-stuff :cursor *stuff* *backup*))
    (render-mouse pmv)))

(defun draw-text-layers (pmv)
  (let ((auxvarw (* *block-width* -1.0 *one-over-window-width*))
	(auxvarh (* *block-height* -1.0 *one-over-window-height*)))
    (flet ((draw-window (rectangle world call-lists chunk-width chunk-height xoffset yoffset)
	     (rescale-screen-matrix *screen-scaled-matrix*
				    (* auxvarw xoffset)
				    (* auxvarh yoffset))
	     (gl:uniform-matrix-4fv pmv *screen-scaled-matrix* nil)
	     (draw-ensure world call-lists
			  (aref rectangle 0)
			  (aref rectangle 2)
			  (aref rectangle 1)
			  (aref rectangle 3)
			  (floor chunk-width)
			  (floor chunk-height))))
      (draw-window *cam-rectangle* *chunks* *chunk-call-lists* 16 16 *camera-x* *camera-y*)
      (draw-window *hud-rectangle* *chunks* *chunk-call-lists* 16 16 *hud-x* *hud-y*))))

(defun rescale-screen-matrix (result x y)
  (setf (cg-matrix:mref result 0 3) x
	(cg-matrix:mref result 1 3) y)
  result)

(defun draw-ensure (world call-lists minx maxx miny maxy chunk-width chunk-height)
  (dobox ((xstart (floor-chunk minx chunk-width) (floor (1+ maxx)) :inc chunk-width)
	  (ystart (floor-chunk miny chunk-height) (floor (1+ maxy)) :inc chunk-height))
	 (let ((index (pix:xy-index xstart ystart)))
	   (multiple-value-bind (value exists) (gethash index call-lists)
	     (declare (ignorable exists))
	     (if value
		 (gl:call-list value)
		 (if (gethash index world)
		     (let ((mesh 
			     (let ((iter *attrib-buffer-iterators*))
			       (let ((buf (get-buf-param iter
							 (etouq (vector 0 8 9 10)))))
				 (reset-attrib-buffer-iterators iter)
				 (let ((times (draw-box-char
					       buf
					       *16x16-tilemap* world
					       xstart (+ xstart chunk-width)
					       ystart (+ ystart chunk-height)
					       *block-width*
					       *block-height*
					       +single-float-just-less-than-one+)))
				   (reset-attrib-buffer-iterators iter)
				   (let ((display-list (gl:gen-lists 1)))
				     (gl:with-new-list (display-list :compile)
				       (gl:with-primitives :quads
					 (mesh-test42 times buf)))
				     display-list))))))
		       (setf (gethash index call-lists) mesh)
		       (gl:call-list mesh))))))))



(defmacro with-vec-params ((&rest bufvars) buf func type &body body)
  (let* ((letargs nil)
	 (counter 0)
	 (syms (mapcar (lambda (x) (gensym (string x))) bufvars))
	 (bindings nil)
	 (decl `(declare (type ,type ,@syms))))
    (dolist (sym syms)
      (push `(,sym (aref ,buf ,counter)) letargs)
      (push `(,(pop bufvars) ,sym) bindings)
      (incf counter))
    `(let ,letargs ,decl
	  (,func ,bindings
		 ,@body))))
(progn
 (defun draw-mouse (bufs
		    lookup value char-width char-height x y z)
   (declare (type single-float x y z char-width char-height)
	    (type simple-vector lookup)
	    (optimize (speed 3) (safety 0))
	    (type fixnum value))
   (with-vec-params (epos etex) bufs iter-ator:wasabios iter-ator:iter-ator
     (multiple-value-bind (x0 y0 x1 y1) (index-quad-lookup lookup value)
       (etouq (ngorp (preach 'etex (duaq 1 nil '(x0 x1 y0 y1))))))
     (let ((x1 (+ char-width x))
	   (y0 (- y char-height)))
       (etouq (ngorp (preach 'epos (quadk+ 'z '(x x1 y0 y))))))
     4))
 
 (defun render-mouse (pmv)       
   (rescale-screen-matrix *screen-scaled-matrix*
			  (* *one-over-window-width* *mouse-x*)
			  (* *one-over-window-height* *mouse-y*))       
   (gl:uniform-matrix-4fv pmv *screen-scaled-matrix* nil)
   (gl:call-list (get-stuff :cursor-list *stuff* *backup*))))

(defun create-call-list-from-func (func &optional (the-list (gl:gen-lists 1)))
  (gl:with-new-list (the-list :compile)
    (funcall func))
  the-list)

(progn
  (declaim (ftype (function (iter-ator:iter-ator fixnum (simple-array t)))
		  attrib-repeat))
  (with-unsafe-speed
    (defun attrib-repeat (buf times vector)
      (iter-ator:wasabios ((ebuf buf))
	(let ((len (length vector)))
	  (dotimes (x times)
	    (dotimes (index len)
	      (let ((value (aref vector index)))
		(ebuf value)))))))))

(defun glinnit ()
  (reset *gl-objects*)
  (setf %gl:*gl-get-proc-address* (e:get-proc-address))
  (clrhash *chunk-call-lists*)
  
  (let ((width (if t 480 854))
	(height (if t 360 480)))
    (window:push-dimensions width height))
  (setf e:*resize-hook* #'on-resize)

  (let ((hash *stuff*))
    (maphash (lambda (k v)
	       (if (integerp v)
		   (remhash k hash)))
	     hash))
  (let ((backup *backup*))

    (progn
      (namexpr backup :cursor-image
	       (lambda ()
		 (flip-image
		  (load-png
		   (img-path #P"cursor/windos-cursor.png")))))
      (namexpr backup :cursor
	       (lambda ()
		 (pic-texture (get-stuff :cursor-image *stuff* *backup*)
			      :rgba
			      *default-tex-params*)))
      (let ((scale 64.0))
	(namexpr *backup* :cursor-list
		 (lambda ()
		   (create-call-list-from-func
		    (lambda ()
		      (let ((iter *attrib-buffer-iterators*))
			(let ((buf (get-buf-param iter (etouq (vector 0 8 9)))))
			  (reset-attrib-buffer-iterators iter)
			  (attrib-repeat (aref buf 2) 4 (vector 1f0 1f0 1f0))
			  (let ((times (draw-mouse
					buf
					*4x4-tilemap* 0
					scale 
					scale
					-2.0 2.0
					(- +single-float-just-less-than-one+))))
			    (reset-attrib-buffer-iterators iter)
			    (gl:with-primitives :quads
			     (mesh-test4269 times buf)))))))))))
    (progn    
      (namexpr backup :textshader
	       (lambda ()
		 (let ((program
			(make-shader-program-from-strings
			 (get-stuff :text-vs *stuff* *backup*)
			 (get-stuff :text-frag *stuff* *backup*)
			 *postex*)))
		   (let ((table (make-eq-hash)))
		     (register program :program table)
		     (cache-program-uniforms program table (quote ((:pmv . "PMV")))))
		   program)))
      
      (namexpr backup :text-vs
	       (lambda () (file-string (shader-path "pos4f-tex2f-bgcol3f-fgcol3f.vs"))))      
      (namexpr backup :text-frag
	       (lambda () (file-string (shader-path "ftex2f-bg3f-fg3f.frag")))))

    (progn

      (namexpr backup :simpleshader
	       (lambda ()
		 (let ((program
			(make-shader-program-from-strings
			 (get-stuff :simple-vs *stuff* *backup*)
			 (get-stuff :simple-frag *stuff* *backup*)
			 *postexcol*)))
		   (let ((table (make-eq-hash)))
		     (register program :program table)
		     (cache-program-uniforms program table (quote ((:pmv . "PMV")))))
		   program)))
      (namexpr backup :simple-vs
	       (lambda () (file-string (shader-path "pos4f-col3f-tex2f.vs"))))
      (namexpr backup :simple-frag
	       (lambda () (file-string (shader-path "fcol3f-ftex2f-no0a.frag")))))
    
    (progn
      (namexpr backup :font-image
	       (lambda ()
		 (flip-image
		  (load-png
		   (img-path #P"font/font.png")))))
      (namexpr backup :font
	       (lambda ()
		 (pic-texture (get-stuff :font-image *stuff* *backup*)
			      :rgba
			      *default-tex-params*))))))

(defun cache-program-uniforms (program table args)
  (dolist (arg args)
    (setf (gethash (car arg) table)
	  (gl:get-uniform-location program (cdr arg)))))
(defun getuniform (shader-info name)
  (gethash name shader-info))

(defun on-resize (w h)
  (setf *window-height* h
	*window-width* w))

(defparameter *buffer-vector-scratch* (make-array 16))

(defun get-buf-param (iter attrib-order &optional (newarray *buffer-vector-scratch*))
  (let ((len (length attrib-order)))
    (dotimes (x len)
      (setf (aref newarray x)
	    (aref iter (aref attrib-order x)))))
  newarray)

(progn

  (defun mesh-test42 (times bufs)
    (with-vec-params (xyz uv eft ebg) bufs iter-ator:wasabiis iter-ator:iter-ator
      (dotimes (x times)
	(%gl:vertex-attrib-2f 8 (uv) (uv))
	(%gl:vertex-attrib-3f 9 (eft) (eft) (eft))
	(%gl:vertex-attrib-3f 10 (ebg) (ebg) (ebg))
	(%gl:vertex-attrib-3f 0 (xyz) (xyz) (xyz)))))

  (progn
    (defun mesh-test4269 (times bufs)
      (with-vec-params (xyz uv eft) bufs iter-ator:wasabiis iter-ator:iter-ator
	(dotimes (x times)
	  (%gl:vertex-attrib-2f 8 (uv) (uv))
	  (%gl:vertex-attrib-3f 9 (eft) (eft) (eft))
	  (%gl:vertex-attrib-3f 0 (xyz) (xyz) (xyz)))))))

(defmacro with-char-colors ((fg-rvar fg-gvar fg-bvar bg-rvar bg-gvar bg-bvar) value &body body)
  `(let ((,fg-rvar (ldb (byte 8 8) ,value))
	 (,fg-gvar (ldb (byte 8 16) ,value))
	 (,fg-bvar (ldb (byte 8 24) ,value))
	 (,bg-rvar (ldb (byte 8 32) ,value))
	 (,bg-gvar (ldb (byte 8 40) ,value))
	 (,bg-bvar (ldb (byte 8 48) ,value)))
     ,@body))

(progn
  (declaim (inline byte-color)
	   (ftype (function (fixnum) single-float)
		  byte-color))
  (with-unsafe-speed
    (defun byte-color (x)
      (/ (float x) 256.0))))

(progn
  (declaim (ftype (function (vector
			     simple-vector
			     pix:pix-world
			     fixnum fixnum fixnum fixnum
			     single-float single-float single-float)
			    fixnum)
		  draw-box-char))
  (with-unsafe-speed
    (defun draw-box-char (bufs
			  lookup world
			  bx0 bx1 by0 by1
			  char-width char-height
			  z)
      (let ((nope 0))
	(with-vec-params (epos etex efg ebg) bufs iter-ator:wasabios iter-ator:iter-ator
	  (dobox ((ix bx0 bx1)
		  (iy by0 by1))
		 (let ((obj (pix:get-obj (pix:xy-index ix iy) world)))
		   (if obj
		       (let ((value (get-char-num obj)))
			 (declare (type fixnum value))
			 (with-char-colors (xfg-r xfg-g xfg-b xbg-r xbg-g xbg-b) value
			   (let ((fg-r (byte-color xfg-r))
				 (fg-g (byte-color xfg-g))
				 (fg-b (byte-color xfg-b))
				 (bg-r (byte-color xbg-r))
				 (bg-g (byte-color xbg-g))
				 (bg-b (byte-color xbg-b)))
			     (dotimes (x 4)
			       (etouq (ngorp (preach 'efg '(fg-r fg-g fg-b))))
			       (etouq (ngorp (preach 'ebg '(bg-r bg-g bg-b)))))))
			 (multiple-value-bind (x0 y0 x1 y1) (index-quad-lookup lookup (mod value 256))
			   (etouq (ngorp (preach 'etex (duaq 1 nil '(x0 x1 y0 y1))))))
			 (let ((foox0 (* (float ix) char-width))
			       (fooy0 (* (float iy) char-height)))
			   (let ((x1 (+ foox0 char-width))
				 (y1 (+ fooy0 char-height)))
			     (etouq (ngorp (preach 'epos (quadk+ 'z '(foox0 x1 fooy0 y1))))))))
		       (incf nope)))))
	(* 4 (- (* (- bx1 bx0) (- by1 by0)) nope))))))
