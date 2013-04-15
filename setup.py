""" Generic setup.py for Cython code. """
from distutils.core import setup
from Cython.Distutils import build_ext
from Cython.Build import cythonize
from Cython.Compiler import Options

# for debbuging, set wraparound and boundscheck to True
DIRECTIVES = dict(
	profile=False,
	cdivision=True,
	nonecheck=False,
	wraparound=False,
	boundscheck=False,
	embedsignature=True,
)

Options.extra_compile_args = ["-O3"]
Options.extra_link_args = ["-O3"] #["-g"]
if __name__ == '__main__':
	setup(name = 'subsequences',
		cmdclass = dict(build_ext=build_ext),
		ext_modules = cythonize('*.pyx',
			nthreads=4,
			annotate=True,
			compiler_directives=DIRECTIVES,
			)
	)
