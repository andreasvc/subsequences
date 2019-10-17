all:
	python3 setup.py build_ext --inplace

.PHONY: clean debug testdebug html lint

clean:
	rm -f *.c *.so

test: all
	python3 subseq.py text1 text2

debug:
	python3-dbg setup.py build_ext --inplace --debug --pyrex-gdb

testdebug: debug valgrind-python.supp
	valgrind --tool=memcheck --leak-check=full --num-callers=30 --suppressions=valgrind-python.supp python3-dbg subseq.py text1 text2

valgrind-python.supp:
	wget http://codespeak.net/svn/lxml/trunk/valgrind-python.supp

lint:
	pylint *py
