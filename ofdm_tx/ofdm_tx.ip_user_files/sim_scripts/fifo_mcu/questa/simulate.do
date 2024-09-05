onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib fifo_mcu_opt

do {wave.do}

view wave
view structure
view signals

do {fifo_mcu.udo}

run -all

quit -force
