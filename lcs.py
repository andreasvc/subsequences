""" Longest common subsequence algorithm, from Wikipedia pseudocode. """
import sys, os

def buildchart(seq1, seq2):
	""" Build chart of LCS lengths. """
	chart = [[0] * (len(seq2)+1) for _ in range(len(seq1)+1)]
	for i, a in enumerate(seq1):
		for j, b in enumerate(seq2):
			if a == b: chart[i][j] = chart[i-1][j-1] + 1
			else: chart[i][j] = max(chart[i][j-1], chart[i-1][j])
	return chart

def backtrack(chart, seq1, seq2, i, j):
	""" extract tuple with LCS from chart and two sequences. """
	if i == -1 or j == -1: return ()
	elif seq1[i] == seq2[j]:
		return backtrack(chart, seq1, seq2, i-1, j-1) + (seq1[i],)
	elif chart[i][j-1] > chart[i-1][j]:
		return backtrack(chart, seq1, seq2, i, j-1)
	return backtrack(chart, seq1, seq2, i-1, j)

def backtrackAll(chart, seq1, seq2, i, j):
	""" extract set of tuples with all LCSes from chart and two sequences.
	This has exponentional worst case complexity since there can be
	exponentionally many longest common subsequences. """
	if i == -1 or j == -1: return set([()])
	if seq1[i] == seq2[j]:
		return set(seq + (seq1[i],)
			for seq in backtrackAll(chart, seq1, seq2, i - 1, j - 1))
	if chart[i][j - 1] >= chart[i - 1][j]:
		result = backtrackAll(chart, seq1, seq2, i, j - 1)
	else: result = set()
	if chart[i - 1][j] >= chart[i][j-1]:
		result.update(backtrackAll(chart, seq1, seq2, i - 1, j))
	return result

def lcs(seq1, seq2):
	return backtrack(buildchart(seq1, seq2), seq1, seq2,
			len(seq1) - 1, len(seq2) - 1)

def test():
	seq1 = tuple("XMJYAUZ")
	seq2 = tuple("MZJAWXU")
	chart = buildchart(seq1, seq2)
	print 'seq1 %r\nseq2 %r\nchart' % (seq1, seq2)
	for a in chart: print a
	print '\nFirst LCS:', lcs(seq1, seq2)

usage = """usage: %s text1 text2
text1 and text2 are filenames, each file containting
one sentence per line, words space separated.""" % sys.argv[0]

def main():
	if len(sys.argv) != 3: print usage
	elif not os.path.exists(sys.argv[1]): print "file not found:", sys.argv[1]
	elif not os.path.exists(sys.argv[2]): print "file not found:", sys.argv[2]

	text1 = [a.split() for a in open(sys.argv[1]).read().splitlines()]
	text2 = [a.split() for a in open(sys.argv[2]).read().splitlines()]
	results = set()

	for sent1 in text1:
		for sent2 in text2:
			results.add(lcs(sent1, sent2))
	results.discard(())
	for subseq in results: print " ".join(subseq)

# given two files, take smallest one and base dictionary on it
# files are tokenized into words and sentences,
# one sent per line, tokens space separated
# dictionary is a mapping of words to nonzero integer IDs
# all words from the other text that are not in this dictionary are mapped to
# the special value 0 (will never be part of a common subsequence).
# now a sentence is represented as an integer array
#   => fast comparisons, low memory usage

if __name__ == '__main__': main()
