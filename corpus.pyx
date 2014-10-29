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

import io
import re
import itertools

# a terminal in a tree in bracket notation is anything between
# a space and a closing paren; use group to extract only the terminal.
terminalsre = re.compile(ur" ([^ )]+)\)")
posterminalsre = re.compile(ur"\(([^ )]+) ([^ )]+)\)")


cdef class Text(object):
	"""Takes a file whose lines are sequences (e.g., sentences) of
	space-delimeted tokens (e.g., words), and compiles it into an array with
	tokens mapped to integers, according to the given mapping."""
	def __init__(self, filename, mapping, encoding='utf8',
			bracket=False, pos=False, strfragment=False, limit=None,
			bint lower=False, bint filtered=False):
		cdef:
			Token maxidx = max(mapping.values()) + 1
			size_t n, m, idx = 0
			list text

		lines = itertools.islice(
				io.open(filename, encoding=encoding),
				None, limit)

		if bracket and pos:
			text = [['/'.join(reversed(tagword))
					for tagword in posterminalsre.findall(line.lower()
						if lower else line)]
					for line in lines]
		elif bracket:
			text = [terminalsre.findall(line.lower() if lower else line)
					for line in lines]
		else:
			text = [line.strip().lower().split() if lower
					else line.strip().split()
					for line in lines]

		if strfragment:
			text = [['#START#'] + sent + ['#STOP#'] for sent in text]
		if filtered:
			text = [[a for a in sent if a in mapping] for sent in text]

		self.length = len(text)
		self.maxlen = max(map(len, text))
		self.seqs = <Sequence *>malloc(len(text) * sizeof(Sequence))
		assert self.seqs is not NULL
		self.tokens = <Token *>malloc(sum(map(len, text)) * sizeof(Token))
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
		"""Free memory."""
		if self.tokens is not NULL:
			free(self.tokens)
			self.tokens = NULL
		if self.seqs is not NULL:
			free(self.seqs)
			self.seqs = NULL


cdef class Comparator(object):
	"""A base class for comparing two Texts to each other."""
	def __init__(self, filename, encoding='utf8', bracket=False, pos=False,
			strfragment=False, limit=None, lower=False, filterre=None):
		self.encoding = encoding
		self.bracket = bracket
		self.pos = pos
		self.strfragment = strfragment
		self.limit = limit
		self.lower = lower
		self.filterre = None if filterre is None else re.compile(filterre)
		self.mapping, self.revmapping = getmapping(filename, encoding,
				bracket, pos, strfragment, lower, self.filterre)
		self.text1 = Text(filename, self.mapping, encoding, bracket, pos,
				strfragment, limit, lower, filterre is not None)

	cdef Text readother(self, filename, bint storetokens=False):
		"""Load the second Text; if filename is None, compare to first text.

		If storetokens is True, add the tokens of the new file to the mapping.
		"""
		cdef Text text2
		if filename is None:
			text2 = self.text1
		else:
			if storetokens:
				extendmapping(self.mapping, self.revmapping, filename,
						self.encoding, self.bracket, self.pos,
						self.strfragment, self.lower, self.filterre)
			text2 = Text(filename, self.mapping, self.encoding, self.bracket,
					self.pos, self.strfragment, self.limit, self.lower,
					self.filterre is not None)
		return text2

	cdef seqtostr(self, Sequence *seq):
		"""Turn the array representation of a sentence back into a sequence of
		string tokens."""
		cdef int n
		return [self.revmapping[seq.tokens[n]] for n in range(seq.length)]


def getmapping(filename, encoding='utf8', bracket=False, pos=False,
		strfragment=False, lower=False, filterre=None):
	"""Create a mapping of tokens to integers and back from a given file."""
	# split file into tokens and turn into set
	data = io.open(filename, encoding=encoding).read()
	if lower:
		data = data.lower()
	if bracket and pos:
		tokens = set(['/'.join(reversed(tagword)) for tagword
				in posterminalsre.findall(data)])
	elif bracket:
		tokens = set(terminalsre.findall(data))
	else:
		tokens = set(data.split())
	if filterre is not None:
		tokens = {a for a in tokens if filterre.match(a) is not None}
	# the empty string '' is used as sentinel token (indicates a gap)
	revmapping = ['']
	if strfragment:
		revmapping.extend(['#START#', '#STOP#'])
	revmapping.extend(tokens)
	mapping = {a: n for n, a in enumerate(revmapping)}
	return mapping, revmapping


def extendmapping(mapping, revmapping, filename, encoding='utf8',
		bracket=False, pos=False, strfragment=False, lower=False,
		filterre=None):
	"""Extend an existing mapping of tokens to integers with tokens
	from a given file."""
	# split file into tokens and turn into set
	data = io.open(filename, encoding=encoding).read()
	if lower:
		data = data.lower()
	if bracket and pos:
		tokens = set(['/'.join(reversed(tagword)) for tagword
				in posterminalsre.findall(data)])
	elif bracket:
		tokens = set(terminalsre.findall(data))
	else:
		tokens = set(data.split())
	if filterre is not None:
		tokens = {a for a in tokens if filterre.match(a) is not None}
	x = len(revmapping)
	newtokens = tokens - mapping.viewkeys()
	revmapping.extend(newtokens)
	mapping.update({a: n for n, a in enumerate(revmapping[x:], x)})
