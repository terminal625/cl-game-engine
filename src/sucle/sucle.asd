(asdf:defsystem #:sucle
  :author "terminal625"
  :license "MIT"
  :description "Cube Demo Game"
  :depends-on
  (
   #:application
   #:alexandria  
   #:utility 
   #:sucle-temp ;;for the terrain picture 
   #:text-subsystem
   #:cl-opengl
   #:glhelp
   #:scratch-buffer
   #:nsb-cga
   #:camera-matrix
   #:quads
   #:sucle-multiprocessing
   #:aabbcc ;;for occlusion culling 
   #:image-utility
   #:uncommon-lisp
   #:fps-independent-timestep
   #:control
   #:alexandria  
   ;;for world-generation
   #:black-tie
   #:ncurses-clone-for-lem
   #:livesupport

   #:sucle-serialize
   #:sqlite
   #:cl-base64)
  :serial t
  :components 
  (
   (:file "queue")
   (:file "voxel-chunks")
   (:file "package")
   (:file "util")
   ;;(:file "block-light") ;;light propogation
   (:file "mesher")
   (:file "block-data")
   (:file "database")
   (:file "world")
   (:file "extra")
   (:file "physics")
   (:file "sucle")
   (:file "render")))
