"""Extract Longest common subsequences from texts."""

# Python imports
from __future__ import print_function, division
from collections import Counter

# Cython imports
from libc.stdlib cimport malloc, free
from corpus cimport Text, Token, Sequence, SeqIdx, Comparator
include "constants.pxi"


cdef class LCSComparator(Comparator):
	"""Load a file after which its longest common subsequences with respect
	to other files can be extracted."""
	def getsequences(self, filename, getall=False, debug=False):
		"""Get the longest common subsequences between the current file
		and another. If filename is None, compare file against itself."""
		cdef:
			Text text2
			SeqIdx *chart
			Sequence result
			Sequence *seq1
			Sequence *seq2
			size_t n, m, nn, mm

		if getall and self.strfragment:
			raise NotImplementedError

		text2 = self.readother(filename)
		chart = <SeqIdx *>malloc(self.text1.maxlen * text2.maxlen
				* sizeof(SeqIdx))
		if chart is NULL:
			raise MemoryError
		result.tokens = <Token *>malloc(min(self.text1.maxlen, text2.maxlen)
				* sizeof(result.tokens[0]))
		if result.tokens is NULL:
			raise MemoryError

		# find subsequences
		results = Counter()
		for n in range(self.text1.length):
			seq1 = &(self.text1.seqs[n])
			for m in range(text2.length):
				seq2 = &(text2.seqs[m])
				if seq1 is seq2:
					continue

				buildchart(chart, seq1, seq2)
				if debug:
<<<<<<< HEAD
					print("seq %d vs. seq %d" % (n, m))
					for nn in range(seq1.length):
						for mm in range(seq2.length):
							print(chart[nn * seq2.length + mm], end=' ')
						print()
					print()
=======
					print "seq %d vs. seq %d" % (n, m)
					for nn in range(seq1.length):
						for mm in range(seq2.length):
							print chart[nn * seq2.length + mm],
						print
					print
>>>>>>> 18a7927f6931c3d6140274c9a8ab1354eb02a49e

				if getall:
					results.update(backtrackall(chart, seq1, seq2,
							seq1.length - 1, seq2.length - 1, self.revmapping))
				else:
					result.length = 0
					backtrack(chart, seq1, seq2, seq1.length - 1,
							seq2.length - 1, &result)
					if debug:
						for n in range(result.length - 1, -1, -1):
							print("%d/%s" % (result.tokens[n],
									self.revmapping[result.tokens[n]]
									if result.tokens[n] < len(self.revmapping)
									else 'ERROR'), end=' ')
						print()
					# increase count for the subsequence that was found
					if (result.length and (not self.strfragment
							or self.makestrfragment(&result))):
						results[tuple(self.seqtostr(&result)[::-1])] += 1
		# clean up
		free(result.tokens)
		free(chart)
		result.tokens = chart = NULL
		if () in results:
			del results[()]
		return results

	def getdistances(self, filename, debug=False):
		"""Compute a distance matrix between the current file and another.
		If filename is None, compare file against itself.

		The returned numpy matrix dist[n, m] has the distance between sentence
		n and m of text1 and text2, respectively.
		
		Distance is computed using the formula:
		
		dist(a, b) = len(LCS(a, b)) / max(len(a), len(b))

		http://hjem.ifi.uio.no/danielry/StringMetric.pdf
		"""
		cdef:
			Text text2
			SeqIdx *chart
			Sequence result
			Sequence *seq1
			Sequence *seq2
			size_t n, m, nn, mm

		text2 = self.readother(filename)
		chart = <SeqIdx *>malloc(self.text1.maxlen * text2.maxlen
				* sizeof(SeqIdx))
		if chart is NULL:
			raise MemoryError
		result.tokens = <Token *>malloc(min(self.text1.maxlen, text2.maxlen)
				* sizeof(result.tokens[0]))
		if result.tokens is NULL:
			raise MemoryError

		import numpy as np
		# find subsequences
		dist = np.zeros((self.text1.length, text2.length), dtype=float) - 1
		for n in range(self.text1.length):
			seq1 = &(self.text1.seqs[n])
			for m in range(text2.length):
				seq2 = &(text2.seqs[m])
				if seq1 is seq2:
					dist[n, m] = 0
					continue

				buildchart(chart, seq1, seq2)
				if debug:
<<<<<<< HEAD
					print("seq %d vs. seq %d" % (n, m))
					for nn in range(seq1.length):
						for mm in range(seq2.length):
							print(chart[nn * seq2.length + mm], end=' ')
						print()
					print()
=======
					print "seq %d vs. seq %d" % (n, m)
					for nn in range(seq1.length):
						for mm in range(seq2.length):
							print chart[nn * seq2.length + mm],
						print
					print
>>>>>>> 18a7927f6931c3d6140274c9a8ab1354eb02a49e

				result.length = 0
				backtrack(chart, seq1, seq2, seq1.length - 1,
						seq2.length - 1, &result)
				if debug:
					for n in range(result.length - 1, -1, -1):
<<<<<<< HEAD
						print("%d/%s" % (result.tokens[n],
								self.revmapping[result.tokens[n]]
								if result.tokens[n] < len(self.revmapping)
								else 'ERROR'), end=' ')
					print()
=======
						print "%d/%s" % (result.tokens[n],
								self.revmapping[result.tokens[n]]
								if result.tokens[n] < len(self.revmapping)
								else 'ERROR'),
					print
>>>>>>> 18a7927f6931c3d6140274c9a8ab1354eb02a49e
				dist[n, m] = 1 - (<double>result.length /
						(seq2.length if seq2.length > seq1.length
						else seq1.length))
		# clean up
		free(result.tokens)
		free(chart)
		result.tokens = chart = NULL
		return dist


	cdef inline bint makestrfragment(self, Sequence *result):
		"""Peel away tokens until sequence is a string fragment;
		or return False when not enough tokens remain."""
		cdef:
			int n = result.length - 1  # idx of first token
			int m = 2  # number of non-gap tokens
		result.length = 0
		# find index of first two consecutive tokens
		# FIXME: might as well do this before making chart
		while n:
			if result.tokens[n]:
				if result.length:
					m += 1
				elif result.tokens[n - 1]:
					result.length = n + 1
			n -= 1
		if result.tokens[1] == GAP and result.tokens[0] == STOP:
			# remove redundant '<gap> #STOP#' sequence
			for n in range(result.length):
				result.tokens[n] = result.tokens[n + 2]
			result.length -= 2
			m -= 1
		if m < 3:
			return False
		return result.length > 0


cdef void buildchart(SeqIdx *chart, Sequence *seq1, Sequence *seq2):
	"""LCS algorithm, from Wikipedia pseudocode.
	Builds chart of LCS lengths."""
	cdef int n, m

	# initialize first row & first column, then loop over rest
	# chart is manually indexed as a 2D array
	for m in range(seq2.length):
		chart[0 * seq2.length + m] = seq1.tokens[0] == seq2.tokens[m]
	for n in range(1, seq1.length):
		chart[n * seq2.length + 0] = seq1.tokens[n] == seq2.tokens[0]
		for m in range(1, seq2.length):
			if seq1.tokens[n] == seq2.tokens[m]:
				chart[n * seq2.length + m] = (
						chart[(n - 1) * seq2.length + (m - 1)] + 1)
			else:
				chart[n * seq2.length + m] = (
						chart[(n - 1) * seq2.length + m]
						if chart[(n - 1) * seq2.length + m] >
							chart[n * seq2.length + (m - 1)]
						else chart[n * seq2.length + (m - 1)])


cdef void backtrack(SeqIdx *chart, Sequence *seq1, Sequence *seq2,
		int n, int m, Sequence *result):
	"""extract tuple with LCS from chart and two sequences.
	From Wikipedia pseudocode.
	NB: if there are multiple subsequences with the maximal length n,
	an arbitrary one will be selected and extracted."""
	if n == -1 or m == -1:
		return
	elif seq1.tokens[n] == seq2.tokens[m]:
		result.tokens[result.length] = seq1.tokens[n]
		result.length += 1
		backtrack(chart, seq1, seq2, n - 1, m - 1, result)
	elif (chart[n * seq2.length + (m - 1)]
			> chart[(n - 1) * seq2.length + m]):
		# add token to indicate gap here; avoid repeats.
		# the gaps are always wrt to the first sequence
		if result.length and result.tokens[result.length - 1] != GAP:
			result.tokens[result.length] = GAP
			result.length += 1
		backtrack(chart, seq1, seq2, n, m - 1, result)
	else:
		backtrack(chart, seq1, seq2, n - 1, m, result)


cdef set backtrackall(SeqIdx *chart, Sequence *seq1, Sequence *seq2,
		int n, int m, list revmapping):
	"""extract set of tuples with all LCSes from chart and two sequences.
	This has exponentional worst case complexity since there can be
	exponentionally many longest common subsequences."""
	if n == -1 or m == -1:
		return set([()])
	elif seq1.tokens[n] == seq2.tokens[m]:
		return set([seq + (revmapping[seq1.tokens[n]],)
			for seq in backtrackall(chart, seq1, seq2, n - 1, m - 1,
			revmapping)])
	elif (chart[n * seq2.length + (m - 1)]
			>= chart[(n - 1) * seq2.length + m]):
		result = backtrackall(chart, seq1, seq2, n, m - 1, revmapping)
	else: result = set()
	if (chart[(n - 1) * seq2.length + m]
			>= chart[n * seq2.length + (m - 1)]):
		result.update(backtrackall(chart, seq1, seq2, n - 1, m, revmapping))
	return result
