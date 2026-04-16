(module
  (memory (export "memory") 1)
  
  (global $width (mut i32) (i32.const 80))
  (global $height (mut i32) (i32.const 40))
  (global $current_buf (mut i32) (i32.const 0))
  
  (func $init (export "init") (param $w i32) (param $h i32)
    (global.set $width (local.get $w))
    (global.set $height (local.get $h))
    (global.set $current_buf (i32.const 0))
    (call $clear)
  )

  (func $get_current_buffer (export "get_current_buffer") (result i32)
    (global.get $current_buf)
  )

  (func $get_width (export "get_width") (result i32)
    (global.get $width)
  )

  (func $get_height (export "get_height") (result i32)
    (global.get $height)
  )

  (func $clear (export "clear")
    (local $i i32)
    (local $max_i i32)
    (local.set $max_i (i32.mul (global.get $width) (global.get $height)))
    (local.set $max_i (i32.mul (local.get $max_i) (i32.const 2)))
    (block $clear_loop_end
      (loop $clear_loop
        (br_if $clear_loop_end (i32.ge_s (local.get $i) (local.get $max_i)))
        (i32.store8 (local.get $i) (i32.const 0))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $clear_loop)
      )
    )
  )

  (func $toggle (export "toggle") (param $x i32) (param $y i32)
    (local $idx i32)
    (local $val i32)
    (local.set $idx (i32.add (global.get $current_buf) (i32.add (i32.mul (local.get $y) (global.get $width)) (local.get $x))))
    (local.set $val (i32.load8_u (local.get $idx)))
    (if (i32.eq (local.get $val) (i32.const 0))
      (then (i32.store8 (local.get $idx) (i32.const 1)))
      (else (i32.store8 (local.get $idx) (i32.const 0)))
    )
  )

  (func $set_cell (export "set_cell") (param $x i32) (param $y i32) (param $state i32)
    (local $idx i32)
    (local.set $idx (i32.add (global.get $current_buf) (i32.add (i32.mul (local.get $y) (global.get $width)) (local.get $x))))
    (i32.store8 (local.get $idx) (local.get $state))
  )

  (func $get_cell (param $x i32) (param $y i32) (result i32)
    (local $idx i32)
    (local.set $idx (i32.add (global.get $current_buf) (i32.add (i32.mul (local.get $y) (global.get $width)) (local.get $x))))
    (i32.load8_u (local.get $idx))
  )

  (func $step (export "step")
    (local $x i32) (local $y i32)
    (local $next_buf i32)
    (local $size i32)
    (local $idx i32) (local $next_idx i32)
    (local $count i32) (local $state i32)
    (local $prev_x i32) (local $next_x i32)
    (local $prev_y i32) (local $next_y i32)

    (local.set $size (i32.mul (global.get $width) (global.get $height)))
    
    (if (i32.eq (global.get $current_buf) (i32.const 0))
      (then (local.set $next_buf (local.get $size)))
      (else (local.set $next_buf (i32.const 0)))
    )

    (local.set $y (i32.const 0))
    (block $y_loop_end
      (loop $y_loop
        (br_if $y_loop_end (i32.ge_s (local.get $y) (global.get $height)))

        ;; Calculate prev_y and next_y
        (local.set $prev_y (i32.sub (local.get $y) (i32.const 1)))
        (if (i32.lt_s (local.get $prev_y) (i32.const 0))
          (then (local.set $prev_y (i32.sub (global.get $height) (i32.const 1))))
        )
        (local.set $next_y (i32.add (local.get $y) (i32.const 1)))
        (if (i32.ge_s (local.get $next_y) (global.get $height))
          (then (local.set $next_y (i32.const 0)))
        )

        (local.set $x (i32.const 0))
        (block $x_loop_end
          (loop $x_loop
            (br_if $x_loop_end (i32.ge_s (local.get $x) (global.get $width)))

            ;; Calculate prev_x and next_x
            (local.set $prev_x (i32.sub (local.get $x) (i32.const 1)))
            (if (i32.lt_s (local.get $prev_x) (i32.const 0))
              (then (local.set $prev_x (i32.sub (global.get $width) (i32.const 1))))
            )
            (local.set $next_x (i32.add (local.get $x) (i32.const 1)))
            (if (i32.ge_s (local.get $next_x) (global.get $width))
              (then (local.set $next_x (i32.const 0)))
            )

            ;; Count neighbors
            (local.set $count (i32.const 0))
            (local.set $count (i32.add (local.get $count) (call $get_cell (local.get $prev_x) (local.get $prev_y))))
            (local.set $count (i32.add (local.get $count) (call $get_cell (local.get $x)      (local.get $prev_y))))
            (local.set $count (i32.add (local.get $count) (call $get_cell (local.get $next_x) (local.get $prev_y))))
            (local.set $count (i32.add (local.get $count) (call $get_cell (local.get $prev_x) (local.get $y))))
            (local.set $count (i32.add (local.get $count) (call $get_cell (local.get $next_x) (local.get $y))))
            (local.set $count (i32.add (local.get $count) (call $get_cell (local.get $prev_x) (local.get $next_y))))
            (local.set $count (i32.add (local.get $count) (call $get_cell (local.get $x)      (local.get $next_y))))
            (local.set $count (i32.add (local.get $count) (call $get_cell (local.get $next_x) (local.get $next_y))))

            ;; Apply rules
            (local.set $state (call $get_cell (local.get $x) (local.get $y)))
            (local.set $next_idx (i32.add (local.get $next_buf) (i32.add (i32.mul (local.get $y) (global.get $width)) (local.get $x))))
            
            (if (i32.eq (local.get $state) (i32.const 1))
              (then
                (if (i32.or (i32.lt_s (local.get $count) (i32.const 2)) (i32.gt_s (local.get $count) (i32.const 3)))
                  (then (i32.store8 (local.get $next_idx) (i32.const 0)))
                  (else (i32.store8 (local.get $next_idx) (i32.const 1)))
                )
              )
              (else
                (if (i32.eq (local.get $count) (i32.const 3))
                  (then (i32.store8 (local.get $next_idx) (i32.const 1)))
                  (else (i32.store8 (local.get $next_idx) (i32.const 0)))
                )
              )
            )

            (local.set $x (i32.add (local.get $x) (i32.const 1)))
            (br $x_loop)
          )
        )
        (local.set $y (i32.add (local.get $y) (i32.const 1)))
        (br $y_loop)
      )
    )

    ;; Swap buffers
    (global.set $current_buf (local.get $next_buf))
  )
)
