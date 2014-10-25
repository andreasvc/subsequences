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
		if not isinstance(self, SubString) or not isinstance(other, SubString):
			return NotImplemented

		me = self
		ob = other
		if me.seq is ob.seq:
			if op == 2:
				return me.start == ob.start and me.end == ob.end
			elif op == 3:
				return me.start != ob.start or me.end != ob.end
		elif (me.end - me.start) == (ob.end - ob.start):
			cmp = memcmp(
					<char *>&(me.seq[me.start]),
					<char *>&(ob.seq[ob.start]),
					me.end - me.start)
			if op == 2:
				return cmp == 0
			elif op == 3:
				return cmp != 0

		return NotImplemented  # no <, >, etc.

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
		return '%s(<%r>)' % (
				self.__class__.__name__,
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
	def getsequences(self, filename, int minmatchsize=1, bint debug=False):
		"""Get the longest common subsequences in two sentence aligned files.
		"""
		cdef:
			Text text2
			SeqIdx *chart
			Sequence *seq1s  # source = text1
			Sequence *seq2s  # source = text1
			Sequence *seq1t  # target = text2
			Sequence *seq2t  # target = text2
			size_t n, m
			set indexset
			dict results = {}
		text2 = self.readother(filename, storetokens=True)
		if self.text1.length != text2.length:
			raise ValueError('Source and target files have different '
					'number of lines')

		# allocate temporary datastructures
		chart = <SeqIdx *>malloc(
				max(self.text1.maxlen,  text2.maxlen) ** 2 * sizeof(SeqIdx))
		if chart is NULL:
			raise MemoryError

		for n in range(self.text1.length):
			seq1s = &(self.text1.seqs[n])
			seq1t = &(text2.seqs[n])
			for m in range(n + 1, self.text1.length):
				seq2s = &(self.text1.seqs[m])
				seq2t = &(text2.seqs[m])

				sourcematches, targetmatches = self.computematch(
						chart, seq1s, seq1t, seq2s, seq2t)
				if debug:
					print('sourcematches', sourcematches)
					print('targetmatches', targetmatches)

				if sourcematches and targetmatches:
					for sourcematch in sourcematches:
						if len(sourcematch) < minmatchsize:
							continue
						for targetmatch in targetmatches:
							if len(targetmatch) < minmatchsize:
								continue
							if sourcematch not in results:
								results[sourcematch] = {}
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
			Sequence *seq1s, Sequence *seq1t,
			Sequence *seq2s, Sequence *seq2t):


		result1 = {longest_common_substring(chart, seq1s, seq2s)}
		# result1 = backtrackall(chart, seq1s, seq2s,
		# 			seq1s.length - 1, seq2s.length - 1, self.revmapping)

		result2 = {longest_common_substring(chart, seq1t, seq2t)}
		#result2 = backtrackall(chart, seq1t, seq2t,
		#			seq1t.length - 1, seq2t.length - 1, self.revmapping)

		# remove exact matches
		return (result1 - result2 - {None}), (result2 - result1 - {None})

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
					out.write('\t\t%s\t%s\n' % (
							self.subtostr(targetmatch), idx))


cdef SubString longest_common_substring(SeqIdx *chart,
		Sequence *seq1, Sequence *seq2):
	cdef SeqIdx longest = 0, x_longest = 0
	cdef int n, m
	for m in range(seq2.length):
		chart[0 * seq2.length + m] = seq1.tokens[0] == seq2.tokens[m]
	for n in range(1, seq1.length):
		chart[n * seq2.length + 0] = seq1.tokens[n] == seq2.tokens[0]
		for m in range(1, seq2.length):
			if seq1.tokens[n - 1] == seq2.tokens[m - 1]:
				chart[n * seq2.length + m] = chart[
						(n - 1) * seq2.length + (m - 1)] + 1
				if chart[n * seq2.length + m] > longest:
					longest = chart[n * seq2.length + m]
					x_longest = n
			else:
				chart[n * seq2.length + m] = 0

	if longest == 0:
		return None
	elif longest > x_longest:
		raise ValueError
	return new_SubString(seq1, x_longest - longest, x_longest)


# cdef set backtrackall(SeqIdx *chart, Sequence *seq1, Sequence *seq2,
# 		int n, int m, list revmapping):
# 	"""Extract set of tuples with all LCSes from chart and two sequences.
# 
# 	This has exponentional worst case complexity since there can be
# 	exponentionally many longest common subsequences."""
# 	if n == -1 or m == -1:
# 		return {()}  # set with the empty tuple
# 	elif seq1.tokens[n] == seq2.tokens[m]:
# 		return set([seq + (revmapping[seq1.tokens[n]], )
# 			for seq in backtrackall(
# 				chart, seq1, seq2, n - 1, m - 1, revmapping)])
# 	elif (chart[n * seq2.length + (m - 1)]
# 			>= chart[(n - 1) * seq2.length + m]):
# 		result = backtrackall(chart, seq1, seq2, n, m - 1, revmapping)
# 	else:
# 		result = set()
# 	if (chart[(n - 1) * seq2.length + m]
# 			>= chart[n * seq2.length + (m - 1)]):
# 		result.update(backtrackall(chart, seq1, seq2, n - 1, m, revmapping))
# 	return result
