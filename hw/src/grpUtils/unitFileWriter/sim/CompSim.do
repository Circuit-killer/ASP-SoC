#----------------------------------*-tcl-*-
do Comp.do

echo "Sim: load design"
set unit FileWriter
vsim -novopt -wlfdeleteonquit \
      work.tb${unit}(Bhv)

echo "Sim: load wave-file(s)"
catch {do wave.do}
#catch {do wave-default.do}
#catch {do ../../unitXYZ/sim/wave-default.do}

echo "Sim: log signals"
log -r /*

echo "Sim: run ..."
 run 500 us

catch {do wave-restore.do}