"""Extract common substrings from sentence aligned corpora."""

from __future__ import print_function
import sys
import itertools

# Cython imports
cimport cython
from libc.stdlib cimport malloc, realloc, free
from libc.stdint cimport uint8_t, uint32_t
from libc.string cimport memcmp
from corpus cimport Text, Token, Sequence, SeqIdx, Comparator
include "constants.pxi"


cdef struct Match:  # total 128 bytes
	uint32_t n  # sentence number 1
	uint32_t m  # sentence number 2
	SeqIdx s1  # source match start idx
	SeqIdx s2  # source match end idx
	SeqIdx t1  # target match start idx
	SeqIdx t2  # target match end idx


@cython.freelist(1000)
cdef class SubString:
	"""A contiguous substring of a Sequence."""
	cdef Sequence *seq
	cdef SeqIdx start, end

	def __richcmp__(self, other, int op):
		cdef int cmp = 0
		cdef SubString me, ob
		if (not isinstance(self, SubString) or not isinstance(other, SubString)
				or op < 2 or op > 3):  # no <, >, etc.
			return NotImplemented

		me = self
		ob = other
		if me.seq is ob.seq and me.start == ob.start and me.end == ob.end:
			return op == 2
		elif (me.end - me.start) == (ob.end - ob.start):
			cmp = memcmp(
					<char *>&(me.seq.tokens[me.start]),
					<char *>&(ob.seq.tokens[ob.start]),
					(me.end - me.start) * sizeof(Token))
			return (op == 2) == (cmp == 0)

	def __hash__(self):
		cdef long n, _hash = 5381
		for n in range(self.start * sizeof(Token), self.end * sizeof(Token)):
			_hash = (_hash << 5) + _hash + (<uint8_t *>self.seq.tokens)[n]
		return _hash

	def __nonzero__(self):
		return self.start != self.end

	def __len__(self):
		return self.end - self.start

	def __repr__(self):
		cdef int n
		return '%s(<%d:%d==%r>)' % (
				self.__class__.__name__, self.start, self.end,
				[self.seq.tokens[n] for n in range(self.start, self.end)])


cdef inline SubString new_SubString(Sequence *seq, SeqIdx start, SeqIdx end):
	cdef SubString substring = SubString.__new__(SubString)
	substring.seq = seq
	substring.start = start
	substring.end = end
	return substring


cdef class ParallelComparator(Comparator):
	"""Load a file after which its parallel substrings with respect
	to other files can be extracted."""
	cdef Text text2
	def getsequences(self, filename, int minmatchsize=1, bint debug=False):
		"""Get common substrings for two sentence aligned files."""
		cdef:
			SeqIdx *chart1
			SeqIdx *chart2
			Sequence *seq1s  # source = text1
			Match *result[1]
			Match *matches
			Match match
			SubString sourcematch, targetmatch
			size_t n, s, t, x
			int nummatches, capacity = 1000
			dict srcstrs = {}
			dict targetstrs = {}
			list revsrcstrs = []
			list revtargetstrs = []
			set indexset
			list table = []
		self.text2 = self.readother(filename, storetokens=True)
		if self.text1.length != self.text2.length:
			raise ValueError('Source and target files have different '
					'number of lines: %d vs %d' % (
					self.text1.length, self.text2.length))

		for n in range(self.text1.length - 1):
			seq1s = &(self.text1.seqs[n])

			# allocate temporary datastructures
			chart1 = <SeqIdx *>malloc(self.text1.maxlen * 3 * sizeof(SeqIdx))
			chart2 = <SeqIdx *>malloc(self.text2.maxlen * 3 * sizeof(SeqIdx))
			if chart1 is NULL or chart2 is NULL:
				raise MemoryError
			result[0] = matches = <Match *>malloc(capacity * sizeof(Match))
			if matches is NULL:
				raise MemoryError

			# the following could be done in a separate thread/process:
			nummatches = getsequencesfor(n, self.text1.length,
					chart1, chart2, self.text1.seqs, self.text2.seqs,
					minmatchsize, result, &capacity)
			if debug:
				print('%d. %s' % (n, ' '.join([
						'%d:%d:%s' % (s, seq1s.tokens[s], a)
						for s, a in enumerate(self.seqtostr(seq1s))])),
						file=sys.stderr)
				for s in range(seq1s.length):
					print('%d:%d' % (s, chart1[s]), end=' ', file=sys.stderr)
				print()
			if nummatches == -1:
				raise ValueError
			matches = result[0]

			for x in range(nummatches):
				match = matches[x]
				sourcematch = new_SubString(
						&(self.text1.seqs[match.n]), match.s1, match.s2)
				targetmatch = new_SubString(
						&(self.text2.seqs[match.n]), match.t1, match.t2)
				if debug:
					print('n=%d, m=%d, s[%d:%d], t[%d:%d]' % (
							match.n, match.m, match.s1, match.s2,
							match.t1, match.t2))
				if sourcematch == targetmatch:
					continue  # FIXME: might want to prune this string globally
				if sourcematch in srcstrs:
					s = srcstrs[sourcematch]
				else:
					s = len(srcstrs)
					srcstrs[sourcematch] = len(srcstrs)
					revsrcstrs.append(sourcematch)
					table.append({})
				if targetmatch in targetstrs:
					t = targetstrs[targetmatch]
					if t in table[s]:
						indexset = table[s][t]
						indexset.add(match.n)
						indexset.add(match.m)
					else:
						table[s][t] = {match.n, match.m}
				else:
					t = len(targetstrs)
					targetstrs[targetmatch] = len(targetstrs)
					revtargetstrs.append(targetmatch)
					table[s][t] = {match.n, match.m}
			free(chart1)
			free(chart2)
			free(matches)

		# clean up
		return table, revsrcstrs, revtargetstrs

	cdef subtostr(self, SubString substring):
		"""Turn the array representation of a substring into a space separated
		string tokens."""
		cdef int n
		return ' '.join([
				self.revmapping[substring.seq.tokens[n]]
				for n in range(substring.start, substring.end)])

	def dumptable(self, table, srcstrs, targetstrs, out):
		for length, srcmatches in itertools.groupby(
				sorted(zip(srcstrs, table), key=lambda x: len(x[0])),
				key=lambda x: len(x[0])):
			out.write('%d:\n' % length)
			for srcmatch, target in srcmatches:
				out.write('\t%s\n' % self.subtostr(srcmatch))
				for targetmatch, idx in target.iteritems():
					out.write('\t\t%s\t{%s}\n' % (
							self.subtostr(targetstrs[targetmatch]),
							','.join([str(a) for a in idx])))


cdef int getsequencesfor(int n, int length,
			SeqIdx *chart1, SeqIdx *chart2,
			Sequence *text1seqs, Sequence *text2seqs,
			int minmatchsize, Match **result, int *capacity) nogil:
	"""Compare sentence n against all sentences starting with n + 1."""
	cdef int nummatches = 0
	cdef int s, t
	cdef Sequence *seq1s
	cdef Sequence *seq2s
	cdef Sequence *seq1t
	cdef Sequence *seq2t
	cdef Match *matches = result[0]
	seq1s = &(text1seqs[n])
	seq1t = &(text2seqs[n])
	for m in range(n + 1, length):
		seq2s = &(text1seqs[m])
		seq2t = &(text2seqs[m])

		longest_common_substrings(chart1, seq1s, seq2s)
		longest_common_substrings(chart2, seq1t, seq2t)

		for s in range(minmatchsize - 1, seq1s.length):
			if (minmatchsize <= chart1[s] <= s + 1
					and (s + 1 == seq1s.length
						or chart1[s + 1] != chart1[s] + 1)):

				for t in range(minmatchsize - 1, seq1t.length):
					if (minmatchsize <= chart2[t] <= t + 1
							and (t + 1 == seq1t.length
								or chart2[t + 1] != chart2[t] + 1)):

						matches[nummatches].n = n
						matches[nummatches].m = m
						matches[nummatches].s1 = s - chart1[s] + 1
						matches[nummatches].s2 = s + 1
						matches[nummatches].t1 = t - chart2[t] + 1
						matches[nummatches].t2 = t + 1
						nummatches += 1

						if nummatches > capacity[0]:
							capacity[0] += capacity[0] // 2
							matches = result[0] = <Match *>realloc(
									matches, capacity[0] * sizeof(Match))
							if matches is NULL:
								return -1
		return nummatches


cdef void longest_common_substrings(SeqIdx *chart,
		Sequence *seq1, Sequence *seq2) nogil:
	"""Return a set of ``SubString`` objects with the longest common substring
	at each position of ``seq1``."""
	cdef int n, m
	# longest[n] == length of common substring starting from n
	cdef SeqIdx *longest = chart
	# temp: current[m] is number of matches up to m and n
	cdef SeqIdx *current = &(chart[seq1.length])
	# temp: prev[m - 1] is number of matches up to m - 1 and n - 1
	cdef SeqIdx *prev = &(chart[seq1.length + seq2.length])

	n = 0
	longest[n] = 0
	for m in range(seq2.length):
		if seq1.tokens[n] == seq2.tokens[m]:
			prev[m] = longest[n] = 1
		else:
			prev[m] = 0

	for n in range(1, seq1.length):
		current[0] = longest[n] = seq1.tokens[n] == seq2.tokens[0]

		for m in range(1, seq2.length):
			if seq1.tokens[n] == seq2.tokens[m]:
				current[m] = prev[m - 1] + 1
				if current[m] > longest[n]:
					longest[n] = current[m]
			else:
				current[m] = 0

		current, prev = prev, current
