""" Extract Longest common subsequences from texts

Approach:
- given two files, take smallest one and base dictionary on it
- files are tokenized into words and sentences,
- one sent per line, tokens space separated
- dictionary is a mapping of words to nonzero integer IDs
- all words from the other text that are not in this dictionary are mapped to
  the special value n (being higher than any word occurring in the other text,
  so will never be part of a common subsequence).
- now a sentence is represented as an integer array
   => fast comparisons, low memory usage
"""

# Python imports
import sys, os, re
from collections import Counter

# Cython imports
from libc.stdlib cimport malloc, free
ctypedef unsigned char UChar
ctypedef unsigned int Token

cdef struct Sequence:
	Token *tokens
	size_t length

# a terminal in a tree in bracket notation is anything between
# a space and a closing paren; use group to extract only the terminal.
terminalsre = re.compile(r" ([^ )]+)\)")
posterminalsre = re.compile(r"\(([^ )]+) ([^ )]+)\)")

cdef class Text(object):
	""" Takes a file whose lines are sequences (e.g., sentences) of
	space-delimeted tokens (e.g., words), and compiles it into an array with
	tokens mapped to integers, according to the given mapping. """

	cdef:
		Sequence *seqs
		Token *tokens # this contiguous array will contain all tokens
		public size_t length, maxlen

	def __init__(self, filename, mapping, bracket=False, pos=False):
		cdef:
			Token maxidx = max(mapping.values()) + 1
			size_t n, m, idx = 0
			list text
		if bracket:
			if pos:
				text = [["/".join(reversed(tagword))
						for tagword in posterminalsre.findall(line)]
						for line in open(filename)]
			else:
				text = [terminalsre.findall(line) for line in open(filename)]
		else:
			text = [line.strip().split() for line in open(filename)]

		self.length = len(text)
		self.maxlen = max(map(len, text))
		self.seqs = <Sequence *>malloc(len(text) * sizeof(Sequence))
		assert self.seqs is not NULL
		self.tokens = <Token *>malloc(sum(map(len, text))
				* sizeof(self.seqs.tokens[0]))
		assert self.tokens is not NULL
		for n, sent in enumerate(text):
			self.seqs[n].tokens = &(self.tokens[idx])
			for m, word in enumerate(sent):
				# NB: if word is not part of mapping,
				# it gets an integer which will never match.
				self.seqs[n].tokens[m] = mapping.get(word, maxidx)
			self.seqs[n].length = len(sent)
			idx += len(sent)

	def __dealloc__(self):
		""" Free memory. """
		if self.tokens is not NULL:
			free(self.tokens)
		if self.seqs is not NULL:
			free(self.seqs)


cdef class Comparator(object):
	cdef:
		Text text1
		dict mapping, revmapping
		bint bracket, pos

	def __init__(self, filename, bracket=False, pos=False):
		self.mapping, self.revmapping = getmapping(filename, bracket, pos)
		self.text1 = Text(filename, self.mapping, bracket, pos)
		self.bracket = bracket
		self.pos = pos

	def getsequences(self, filename, getall=False, debug=False):
		cdef:
			Text text2
			UChar *chart
			Sequence result, *seq1, *seq2
			size_t n, m

		# read data
		text2 = Text(filename, self.mapping, self.bracket, self.pos)
		chart = <UChar *>malloc(self.text1.maxlen * text2.maxlen * sizeof(UChar))
		assert chart is not NULL
		result.tokens = <Token *>malloc(min(self.text1.maxlen, text2.maxlen)
				* sizeof(result.tokens[0]))
		assert result.tokens is not NULL

		# find subsequences
		results = Counter()
		for n in range(self.text1.length):
			seq1 = &(self.text1.seqs[n])
			for m in range(text2.length):
				seq2 = &(text2.seqs[m])
				buildchart(chart, seq1, seq2)
				if debug:
					for n in range(seq1.length):
						for m in range(seq2.length):
							print chart[n * seq2.length + m],
						print

				if getall:
					results.update(backtrackAll(chart, seq1, seq2,
							seq1.length - 1, seq2.length - 1, self.revmapping))
				else:
					result.length = 0
					backtrack(chart, seq1, seq2, seq1.length - 1, seq2.length - 1,
							&result)
					## increase count for the subsequence that was found
					results[getresult(&result, self.revmapping)] += 1
		# clean up
		free(result.tokens)
		free(chart)
		del results[()]
		return results

def getmapping(filename, bracket=False, pos=False):
	""" Create a mapping of tokens to integers and back from a given file. """
	# the sentinel token will be the empty string '' (used to indicate gaps)
	mapping = {'': 0}
	revmapping = {0: ''}
	# split file into tokens and turn into set
	if bracket:
		if pos:
			tokens = set(["/".join(reversed(tagword)) for tagword
					in posterminalsre.findall(open(filename).read())])
		else:
			tokens = set(terminalsre.findall(open(filename).read()))
	else:
		tokens = set(open(filename).read().split())
	# iterate over set & assign IDs
	for n, a in enumerate(tokens, 1):
		mapping[a] = n
		revmapping[n] = a
	return mapping, revmapping

cdef void buildchart(UChar *chart, Sequence *seq1, Sequence *seq2):
	""" LCS algorithm, from Wikipedia pseudocode.
	Builds chart of LCS lengths. """
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

cdef void backtrack(UChar *chart, Sequence *seq1, Sequence *seq2,
		int n, int m, Sequence *result):
	""" extract tuple with LCS from chart and two sequences.
	From Wikipedia pseudocode. """
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
		if result.length and result.tokens[result.length - 1] != 0:
			result.tokens[result.length] = 0
			result.length += 1
		backtrack(chart, seq1, seq2, n, m - 1, result)
	else:
		backtrack(chart, seq1, seq2, n - 1, m, result)

cdef set backtrackAll(UChar *chart, Sequence *seq1, Sequence *seq2,
		int n, int m, dict revmapping):
	""" extract set of tuples with all LCSes from chart and two sequences.
	This has exponentional worst case complexity since there can be
	exponentionally many longest common subsequences. """
	if n == -1 or m == -1:
		return set([()])
	elif seq1.tokens[n] == seq2.tokens[m]:
		return set([seq + (revmapping[seq1.tokens[n]],)
			for seq in backtrackAll(chart, seq1, seq2, n - 1, m - 1,
			revmapping)])
	elif (chart[n * seq2.length + (m - 1)]
			>= chart[(n - 1) * seq2.length + m]):
		result = backtrackAll(chart, seq1, seq2, n, m - 1, revmapping)
	else: result = set()
	if (chart[(n - 1) * seq2.length + m]
			>= chart[n * seq2.length + (m - 1)]):
		result.update(backtrackAll(chart, seq1, seq2, n - 1, m, revmapping))
	return result

cdef tuple getresult(Sequence *seq, dict revmapping):
	""" Turn the array representation of a sentence back into a sequence of
	string tokens. """
	cdef:
		int n
		list result = []
	# reverse the result
	for n in range(seq.length - 1, -1, -1):
		result.append(revmapping[seq.tokens[n]])
	return tuple(result)

