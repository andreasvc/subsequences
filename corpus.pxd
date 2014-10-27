
# Cython imports
from libc.stdlib cimport malloc, free
from libc.stdint cimport uint16_t, uint32_t
ctypedef uint16_t SeqIdx
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
	cdef bint bracket, pos, strfragment, lower
	cdef object limit, filterre, encoding
	cdef Text readother(self, filename, bint storetokens=*)
	cdef seqtostr(self, Sequence *seq)
