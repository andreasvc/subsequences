all:
	python setup.py build_ext --inplace

.PHONY: clean debug testdebug html lint

clean:
	rm -f *.c *.so

test: all
	python lcs.py text1 text2

debug:
	python-dbg setup.py build_ext --inplace --debug --pyrex-gdb

testdebug: debug valgrind-python.supp
	valgrind --tool=memcheck --leak-check=full --num-callers=30 --suppressions=valgrind-python.supp python-dbg lcs.py text1 text2

valgrind-python.supp:
	wget http://codespeak.net/svn/lxml/trunk/valgrind-python.supp

lint:
	pylint *py
