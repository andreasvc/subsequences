"""Extract common substrings from sentence aligned corpora."""

import itertools

# Cython imports
from libc.stdlib cimport malloc, free
from libc.stdint cimport uint8_t
from libc.string cimport memcmp
from corpus cimport Text, Token, Sequence, SeqIdx, Comparator
include "constants.pxi"


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
					<char *>&(me.seq[me.start]),
					<char *>&(ob.seq[ob.start]),
					(me.end - me.start) * sizeof(Token))
			return (op == 2) == (cmp == 0)

	def __hash__(self):
		cdef long n, _hash = -1
		for n in range(self.start * sizeof(Token), self.end * sizeof(Token)):
			_hash *= 33 ^ (<uint8_t *>self.seq)[n]
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
			SeqIdx *chart
			Sequence *seq1s  # source = text1
			Sequence *seq2s  # source = text1
			Sequence *seq1t  # target = text2
			Sequence *seq2t  # target = text2
			size_t n, m
			set indexset
			dict results = {}
		self.text2 = self.readother(filename, storetokens=True)
		if self.text1.length != self.text2.length:
			raise ValueError('Source and target files have different '
					'number of lines')

		# allocate temporary datastructures
		chart = <SeqIdx *>malloc(
				((max(self.text1.maxlen,  self.text2.maxlen) + 1) ** 2)
				* sizeof(SeqIdx))
		if chart is NULL:
			raise MemoryError

		for n in range(self.text1.length):
			seq1s = &(self.text1.seqs[n])
			seq1t = &(self.text2.seqs[n])
			for m in range(n + 1, self.text1.length):
				seq2s = &(self.text1.seqs[m])
				seq2t = &(self.text2.seqs[m])

				result1 = self.computematch(
						chart, seq1s, seq2s, minmatchsize, debug)
				result2 = self.computematch(
						chart, seq1t, seq2t, minmatchsize, debug)
				# remove exact matches between source & target
				sourcematches = result1 - result2
				targetmatches = result2 - result1
				if debug:
					print('sourcematches', sourcematches)
					print('targetmatches', targetmatches)

				if sourcematches and targetmatches:
					for sourcematch in sourcematches:
						if sourcematch not in results:
							results[sourcematch] = {}
						for targetmatch in targetmatches:
							if targetmatch not in results[sourcematch]:
								results[sourcematch][targetmatch] = set()
							indexset = results[sourcematch][targetmatch]
							indexset.add(n)
							indexset.add(m)

		# clean up
		free(chart)
		chart = NULL
		return results

	cdef computematch(self, SeqIdx *chart,
			Sequence *seq1, Sequence *seq2,
			int minmatchsize, bint debug):
		result = longest_common_substrings(chart, seq1, seq2, minmatchsize)
		if debug:
			print('\t' + ' '.join(self.seqtostr(seq2)))
			for n in range(seq1.length):
				print self.revmapping[seq1.tokens[n]] + '\t',
				for m in range(seq2.length + 1):
					print chart[n * (seq2.length + 1) + m],
				print
			print
		return result

	cdef str subtostr(self, SubString substring):
		"""Turn the array representation of a substring into a space separated
		string tokens."""
		cdef int n
		try:
			return ' '.join([
					self.revmapping[substring.seq.tokens[n]]
					for n in range(substring.start, substring.end)])
		except IndexError:
			print(substring)
			raise

	def dumptable(self, results, out):
		for length, srcmatches in itertools.groupby(
				sorted(results, key=len), key=len):
			out.write('%d:\n' % length)
			for srcmatch in srcmatches:
				out.write('\t%s\n' % self.subtostr(srcmatch))
				for targetmatch, idx in results[srcmatch].iteritems():
					out.write('\t\t%s\t{%s}\n' % (
							self.subtostr(targetmatch),
							','.join([str(a) for a in idx])))


cdef set longest_common_substrings(SeqIdx *chart,
		Sequence *seq1, Sequence *seq2, int minmatchsize):
	"""Return a set of ``SubString`` objects with the longest common substring
	at each position of ``seq1``."""
	cdef int n, m, cols = seq2.length + 1

	# NB: ``chart[n * cols + m]`` means ``chart[n][m]``
	# last column stores longest match for each n
	chart[0 * cols + seq2.length] = 0
	for m in range(seq2.length):
		if seq1.tokens[0] == seq2.tokens[m]:
			chart[0 * cols + m] = chart[0 * cols + seq2.length] = 1
		else:
			chart[0 * cols + m] = 0

	for n in range(1, seq1.length):
		chart[n * cols + 0] = chart[n * cols + seq2.length] = (
				seq1.tokens[n] == seq2.tokens[0])
		for m in range(1, seq2.length):
			if seq1.tokens[n - 1] == seq2.tokens[m - 1]:
				chart[n * cols + m] = chart[
						(n - 1) * cols + (m - 1)] + 1
				if (chart[n * cols + m] >
						chart[n * cols + seq2.length]):
					chart[n * cols + seq2.length] = chart[
							n * cols + m]
			else:
				chart[n * cols + m] = seq1.tokens[n] == seq2.tokens[m]

	return {new_SubString(seq1, n - chart[n * cols + seq2.length] + 1, n + 1)
			for n in range(seq1.length)
			if minmatchsize <= chart[n * cols + seq2.length] <= n + 1
			and (n == seq1.length - 1
				or chart[(n + 1) * cols + seq2.length] == 0)}
