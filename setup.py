""" Generic setup.py for Cython code. """
from distutils.core import setup
from Cython.Build import cythonize
from Cython.Distutils import build_ext
from Cython.Compiler import Options

Options.fast_fail = True
Options.extra_compile_args = ['-O3']
Options.extra_link_args = ['-O3'] #['-g']

# for debugging, set wraparound and boundscheck to True
DIRECTIVES = {
                'profile': False,
                'cdivision': True,
                'nonecheck': False,
                'wraparound': False,
                'boundscheck': False,
                'embedsignature': True,
                'warn.unused': True,
                'warn.unreachable': True,
                'warn.maybe_uninitialized': True,
                'warn.undeclared': False,
                'warn.unused_arg': False,
                'warn.unused_result': False,
                }


METADATA = dict(
		name='subsequences',
		version='0.1pre1',
		description='Extract Subsequences from Text Corpora',
		long_description=open('README.md').read(),
		author='Andreas van Cranenburgh',
		author_email='A.W.vanCranenburgh@uva.nl',
		url='https://github.com/andreasvc/subsequences/',
		classifiers=[
				'Development Status :: 4 - Beta',
				'Environment :: Console',
				'Environment :: Web Environment',
				'Intended Audience :: Science/Research',
				'License :: OSI Approved :: GNU General Public License (GPL)',
				'Operating System :: POSIX',
				'Programming Language :: Python :: 2.7',
				'Programming Language :: Python :: 3.3',
				'Programming Language :: Cython',
				'Topic :: Text Processing :: Linguistic',
		],
		requires=['cython (>=0.20)'],
)

if __name__ == '__main__':
	setup(
			cmdclass=dict(build_ext=build_ext),
			ext_modules=cythonize('*.pyx',
				# nthreads=4,
				annotate=True,
				compiler_directives=DIRECTIVES,
				),
			**METADATA)
