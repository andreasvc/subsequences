
# Cython imports
from libc.stdlib cimport malloc, free
from libc.stdint cimport uint8_t, uint32_t
ctypedef uint8_t UChar
ctypedef uint32_t Token
include "constants.pxi"


cdef struct Sequence:
	# Represents a sequence of tokens after it has been mapped to numeric
	# identifiers.
	Token *tokens
	int length


cdef class Text(object):
	cdef Sequence *seqs
	cdef Token *tokens # this contiguous array will contain all tokens
	cdef public int length, maxlen


cdef class Comparator(object):
	cdef Text text1
	cdef dict mapping
	cdef list revmapping
	cdef bint bracket, pos, strfragment
	cdef Text readother(self, filename)
	cdef tuple getresult(self, Sequence *seq)
