""" Longest common subsequence algorithm, from Wikipedia pseudocode. """

def main():
	seq1 = tuple("XMJYAUZ")
	seq2 = tuple("MZJAWXU")
	chart = lcs(seq1, seq2)
	print 'seq1 %r\nseq2 %r\nchart' % (seq1, seq2)
	for a in chart: print a
	print '\nFirst LCS:', backtrack(chart, seq1, seq2, len(seq1)-1, len(seq2)-1)

def lcs(seq1, seq2):
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

if __name__ == '__main__': main()
