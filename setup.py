#!/usr/bin/env python3
from distutils.extension import Extension
from distutils.core import setup
from Cython.Distutils import build_ext

# _perf = Extension('_perf',
                    # sources = ['_perf.c'], extra_compile_args=["-std=gnu99"])

#flags = ["-std=gnu99","-ggdb"]
flags = ["-std=gnu99"]

perfstat = Extension('perfstat',
	sources=['perfstat.pyx', '_perf.c'],
	extra_compile_args=flags)


setup(
  name = 'perfstat',
  version = '1.0',
  cmdclass = {'build_ext': build_ext},
  ext_modules = [perfstat]
)
