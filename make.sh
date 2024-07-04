if [ ! -d tmp ]; then
	mkdir tmp
fi

# for i in cbmbasic1 cbmbasic2 kbdbasic osi kb9 applesoft microtan aim65 sym1; do
for i in beneater; do

echo $i
ca65 -D $i -v -g -l tmp/program.lst msbasic.s -o tmp/$i.o &&
ld65 -C $i.cfg tmp/$i.o -o tmp/$i.bin -Ln tmp/$i.lbl -m tmp/program.map
da65 --cpu 65c02 tmp/$i.bin -o tmp/$i.asm
done

