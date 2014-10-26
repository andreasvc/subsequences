"""Load a corpus and store as array of integers.

Approach:
- given two files, take smallest one and base dictionary on it
- files are tokenized into words and sentences,
- one sent per line, tokens space separated
- dictionary is a mapping of words to nonzero integer IDs
- all words from the other text that are not in this dictionary are mapped to
  the special value n (being higher than any word occurring in the other text,
  so will never be part of a common subsequence).
- now a sentence is represented as an integer array
   => fast comparisons, low memory usage.
"""

import re

# a terminal in a tree in bracket notation is anything between
# a space and a closing paren; use group to extract only the terminal.
terminalsre = re.compile(r" ([^ )]+)\)")
posterminalsre = re.compile(r"\(([^ )]+) ([^ )]+)\)")


cdef class Text(object):
	"""Takes a file whose lines are sequences (e.g., sentences) of
	space-delimeted tokens (e.g., words), and compiles it into an array with
	tokens mapped to integers, according to the given mapping."""
	def __init__(self, filename, mapping, bracket=False, pos=False,
			strfragment=False):
		cdef:
			Token maxidx = max(mapping.values()) + 1
			size_t n, m, idx = 0
			list text

		if bracket and pos:
			text = [["/".join(reversed(tagword))
					for tagword in posterminalsre.findall(line)]
					for line in open(filename)]
		elif bracket:
			text = [terminalsre.findall(line) for line in open(filename)]
		else:
			text = [line.strip().split() for line in open(filename)]
		if strfragment:
			text = [['#START#'] + sent + ['#STOP#'] for sent in text]

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
			self.tokens = NULL
		if self.seqs is not NULL:
			free(self.seqs)
			self.seqs = NULL


cdef class Comparator(object):
	"""A base class for comparing two Texts to each other."""
	def __init__(self, filename, bracket=False, pos=False,
			strfragment=False):
		self.mapping, self.revmapping = getmapping(filename, bracket, pos,
				strfragment)
		self.text1 = Text(filename, self.mapping, bracket, pos, strfragment)
		self.bracket = bracket
		self.pos = pos
		self.strfragment = strfragment

	cdef Text readother(self, filename, bint storetokens=False):
		"""Load the second Text; if filename is None, compare to first text.

		If storetokens is True, add the tokens of the new file to the mapping.
		"""
		if filename is None:
			text2 = self.text1
		else:
			if storetokens:
				extendmapping(self.mapping, self.revmapping, filename,
						self.bracket, self.pos)
			text2 = Text(filename, self.mapping, self.bracket, self.pos)
		return text2

	cdef tuple seqtostr(self, Sequence *seq):
		"""Turn the array representation of a sentence back into a sequence of
		string tokens."""
		cdef int n
		return tuple([self.revmapping[seq.tokens[n]]
				for n in range(seq.length)])


def getmapping(filename, bracket=False, pos=False, strfragment=False):
	"""Create a mapping of tokens to integers and back from a given file."""
	# split file into tokens and turn into set
	if bracket and pos:
		tokens = set(["/".join(reversed(tagword)) for tagword
				in posterminalsre.findall(open(filename).read())])
	elif bracket:
		tokens = set(terminalsre.findall(open(filename).read()))
	else:
		tokens = set(open(filename).read().split())
	# the empty string '' is used as sentinel token (indicates a gap)
	revmapping = ['']
	if strfragment:
		revmapping.extend(['#START#', '#STOP#'])
	revmapping.extend(tokens)
	mapping = {a: n for n, a in enumerate(revmapping)}
	return mapping, revmapping


def extendmapping(mapping, revmapping, filename,
		bracket=False, pos=False, strfragment=False):
	"""Extend an existing mapping of tokens to integers with tokens
	from a given file."""
	# split file into tokens and turn into set
	if bracket and pos:
		tokens = set(["/".join(reversed(tagword)) for tagword
				in posterminalsre.findall(open(filename).read())])
	elif bracket:
		tokens = set(terminalsre.findall(open(filename).read()))
	else:
		tokens = set(open(filename).read().split())
	x = len(revmapping)
	newtokens = tokens - mapping.viewkeys()
	revmapping.extend(newtokens)
	mapping.update({a: n for n, a in enumerate(revmapping[x:], x)})
