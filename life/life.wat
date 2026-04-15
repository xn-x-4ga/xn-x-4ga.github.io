(module
  ;; Importamos la memoria desde el host (JS)
  (import "env" "memory" (memory 1))

  ;; Variables globales de dimensiones
  (global $width (mut i32) (i32.const 0))
  (global $height (mut i32) (i32.const 0))

  ;; --- FUNCIÓN: Inicialización ---
  (func (export "init") (param $w i32) (param $h i32)
    local.get $w
    global.set $width
    local.get $h
    global.set $height
  )

  ;; --- FUNCIÓN INTERNA: Obtener celda (Toroidal) ---
  (func $getCell (param $ptr i32) (param $x i32) (param $y i32) (result i32)
    (local $nx i32)
    (local $ny i32)

    ;; nx = (x + width) % width
    local.get $x
    global.get $width
    i32.add
    global.get $width
    i32.rem_s
    local.set $nx

    ;; ny = (y + height) % height
    local.get $y
    global.get $height
    i32.add
    global.get $height
    i32.rem_s
    local.set $ny

    ;; return memory[ptr + (ny * width + nx)]
    local.get $ptr
    local.get $ny
    global.get $width
    i32.mul
    local.get $nx
    i32.add
    i32.add
    i32.load8_u
  )

  ;; --- FUNCIÓN: Evolución de Generación ---
  (func (export "nextGen") (param $currentPtr i32) (param $nextPtr i32)
    (local $x i32)
    (local $y i32)
    (local $count i32)
    (local $self i32)

    (local.set $y (i32.const 0))
    (loop $y_loop
      (local.set $x (i32.const 0))
      (loop $x_loop
        
        ;; Sumar los 8 vecinos
        (local.set $count (i32.const 0))
        local.get $currentPtr local.get $x i32.const 1 i32.sub local.get $y i32.const 1 i32.sub call $getCell
        local.get $currentPtr local.get $x               local.get $y i32.const 1 i32.sub call $getCell i32.add
        local.get $currentPtr local.get $x i32.const 1 i32.add local.get $y i32.const 1 i32.sub call $getCell i32.add
        local.get $currentPtr local.get $x i32.const 1 i32.sub local.get $y               call $getCell i32.add
        local.get $currentPtr local.get $x i32.const 1 i32.add local.get $y               call $getCell i32.add
        local.get $currentPtr local.get $x i32.const 1 i32.sub local.get $y i32.const 1 i32.add call $getCell i32.add
        local.get $currentPtr local.get $x               local.get $y i32.const 1 i32.add call $getCell i32.add
        local.get $currentPtr local.get $x i32.const 1 i32.add local.get $y i32.const 1 i32.add call $getCell i32.add
        local.set $count

        ;; Estado actual de la celda
        local.get $currentPtr local.get $x local.get $y call $getCell
        local.set $self

        ;; Calcular dirección de memoria para guardar resultado
        local.get $nextPtr
        local.get $y
        global.get $width
        i32.mul
        local.get $x
        i32.add
        i32.add

        ;; Aplicar Reglas de Conway
        local.get $self
        if (result i32)
          local.get $count i32.const 2 i32.eq
          local.get $count i32.const 3 i32.eq
          i32.or
        else
          local.get $count i32.const 3 i32.eq
        end

        ;; Guardar (0 = Muerta, 1 = Viva)
        i32.store8

        ;; Control de bucle X
        local.get $x i32.const 1 i32.add local.tee $x
        global.get $width i32.lt_s
        br_if $x_loop
      )
      ;; Control de bucle Y
      local.get $y i32.const 1 i32.add local.tee $y
      global.get $height i32.lt_s
      br_if $y_loop
    )
  )

  ;; --- FUNCIÓN: Renderizado a Píxeles (Framebuffering) ---
  (func (export "render") (param $currentPtr i32) (param $pixelPtr i32)
    (local $i i32)
    (local $total i32)
    (local $isAlive i32)

    global.get $width
    global.get $height
    i32.mul
    local.set $total
    
    (local.set $i (i32.const 0))
    (loop $pixel_loop
      ;; Dirección del píxel en el array RGBA (4 bytes por píxel)
      local.get $pixelPtr
      local.get $i
      i32.const 4
      i32.mul
      i32.add

      ;; Leer estado de la celda lógica
      local.get $currentPtr
      local.get $i
      i32.add
      i32.load8_u
      local.set $isAlive

      ;; Si está viva, pintar negro (0xFF000000). Si no, blanco (0xFFFFFFFF).
      ;; Nota: Formato Little-endian en memoria (AABBGGRR)
      local.get $isAlive
      if (result i32)
        i32.const 0xFF000000 ;; Negro opaco
      else
        i32.const 0xFFFFFFFF ;; Blanco opaco
      end
      
      i32.store ;; Escribir 4 bytes de color de una vez
      
      ;; Incrementar índice
      local.get $i i32.const 1 i32.add local.tee $i
      local.get $total i32.lt_s
      br_if $pixel_loop
    )
  )
)
