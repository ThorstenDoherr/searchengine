#include <time.h>
#include <math.h>
#include <stdio.h>
#include <pro_ext.h>

#define BUFFERSIZE 25000000

typedef struct
{	double *array;
	long rows;
	long cols;
} AHandle;

static AHandle ArrayHandler[65000];
static FILE *F[65000];
static char FAR buffer[BUFFERSIZE+2];

void FAR FoxproVersion(ParamBlk FAR *parm)
{	_RetInt(101,10);
}

long FAR FileOpen(ParamBlk FAR *parm, char *mode)
{	char FAR *filename;
	
	if (!_SetHandSize(parm->p[1].val.ev_handle, parm->p[1].val.ev_length+1)) _Error(182);
	((char FAR *) _HandToPtr(parm->p[1].val.ev_handle))[parm->p[1].val.ev_length] = '\0';
	_HLock(parm->p[1].val.ev_handle);
	filename = (char FAR *) _HandToPtr(parm->p[1].val.ev_handle);
	_HUnLock(parm->p[1].val.ev_handle);
	F[parm->p[0].val.ev_long] = fopen(filename, mode);
	if (F[parm->p[0].val.ev_long] != NULL) return parm->p[0].val.ev_long;
	return -1;
}

void FAR FileOpenRead(ParamBlk FAR *parm)
{	_RetInt(FileOpen(parm, "rb"),10);
}

void FAR FileOpenWrite(ParamBlk FAR *parm)
{	_RetInt(FileOpen(parm, "wb"),10);
}

void FAR FileOpenAppend(ParamBlk FAR *parm)
{	_RetInt(FileOpen(parm, "ab"),10);
}

void FAR FileClose(ParamBlk FAR *parm)
{	if (F[parm->p[0].val.ev_long] != NULL) 
	{	fclose(F[parm->p[0].val.ev_long]);
		_RetInt(parm->p[0].val.ev_long,10);
	}
	else
	{	_RetInt(-1,10);
	}
}

void FAR FileRewind(ParamBlk FAR *parm)
{	rewind(F[parm->p[0].val.ev_long]);
}

void FAR FileEOF(ParamBlk FAR *parm)
{	_RetLogical(feof(F[parm->p[0].val.ev_long]));
}

void FAR FileRead(ParamBlk FAR *parm)
{	FILE *f;
	int c;
	long len, pos = 0;
	
	f = F[parm->p[0].val.ev_long];
	len = parm->p[1].val.ev_long;
	if (len >= BUFFERSIZE)
	{	len = BUFFERSIZE-1;
	}
	while (len > 0)
	{	c = getc(f);
		if (c == EOF) break;
		buffer[pos] = (char) c;
		pos++;
		len--;
	}
	if (c == EOF && pos > 0) clearerr(f);
	buffer[pos] = '\0';
	_RetChar(buffer);
}

void FAR FileReadCRLF(ParamBlk FAR *parm)
{	FILE *f;
	int cr, lf;
	long pos = 0;
	
	f = F[parm->p[0].val.ev_long];
	while (1)
	{	cr = getc(f);
		if (cr == 13)
		{	lf = getc(f);
			if (lf == 10) break;
			buffer[pos] = (char) cr;
			pos++;
			cr = lf;
		}
		if (cr == EOF) break;
		buffer[pos] = (char) cr;
		pos++;
		if (pos > BUFFERSIZE) break;
	}
	if (cr == EOF && pos > 0) clearerr(f);
	buffer[pos] = '\0';
	_RetChar(buffer);
}

void FAR FileReadLF(ParamBlk FAR *parm)
{	FILE *f;
	int lf;
	long pos = 0;
	
	f = F[parm->p[0].val.ev_long];
	while (1)
	{	lf = getc(f);
		if (lf == 10) break;
		if (lf == EOF) break;
		buffer[pos] = (char) lf;
		pos++;
		if (pos > BUFFERSIZE) break;
	}
	if (lf == EOF && pos > 0) clearerr(f);
	buffer[pos] = '\0';
	_RetChar(buffer);
}

void FAR FileSize(ParamBlk FAR *parm)
{	FILE *f;
	long size;
	fpos_t pos;
	
	f = F[parm->p[0].val.ev_long];
	fgetpos(f, &pos);
	fseek(f, 0L, SEEK_END);
	size = ftell(f);
	fsetpos(f, &pos);
	_RetInt(size, 18);
}

void FAR FilePos(ParamBlk FAR *parm)
{	FILE *f;
	
	f = F[parm->p[0].val.ev_long];
	_RetInt(ftell(f),18);
}

void FAR FileWrite(ParamBlk FAR *parm)
{	size_t size;

	_HLock(parm->p[1].val.ev_handle);
	size = fwrite(_HandToPtr(parm->p[1].val.ev_handle), 1 , parm->p[1].val.ev_length, F[parm->p[0].val.ev_long]);
	_HUnLock(parm->p[1].val.ev_handle);
	if (size == parm->p[1].val.ev_length)
	{	_RetInt(size, 18);
	}
	else
	{	_RetInt(-1, 18);
	}
}

void FAR FileWriteCRLF(ParamBlk FAR *parm)
{	FILE *f;
	size_t size;
	
	f = F[parm->p[0].val.ev_long];
	_HLock(parm->p[1].val.ev_handle);
	size = fwrite(_HandToPtr(parm->p[1].val.ev_handle), 1 , parm->p[1].val.ev_length, f);
	_HUnLock(parm->p[1].val.ev_handle);
	if (size == parm->p[1].val.ev_length && putc(13, f) != EOF && putc(10, f) != EOF)
	{	_RetInt(size+2, 18);
	}
	else
	{	_RetInt(-1, 18);
	}
}

void FAR FileWriteLF(ParamBlk FAR *parm)
{	FILE *f;
	size_t size;
	
	f = F[parm->p[0].val.ev_long];
	_HLock(parm->p[1].val.ev_handle);
	size = fwrite(_HandToPtr(parm->p[1].val.ev_handle), 1 , parm->p[1].val.ev_length, f);
	_HUnLock(parm->p[1].val.ev_handle);
	if (size == parm->p[1].val.ev_length && putc(10, f) != EOF)
	{	_RetInt(size+1, 18);
	}
	else
	{	_RetInt(-1, 18);
	}
}

void FAR FileGo(ParamBlk FAR *parm) // jumps to file position (starting at zero)
{	FILE *f;
	double pos;
	
	f = F[parm->p[0].val.ev_long];
	pos = parm->p[1].val.ev_real;
	fseek(f, 0L, SEEK_SET);
	while (pos > 1)
	{	pos--;
		if (getc(f) == EOF)
		{	_RetLogical(0);
			return;
		}
	}
	_RetLogical(1);
}

void FAR OpenArray(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	
	ah = &(ArrayHandler[parm->p[0].val.ev_long]);
	delete ArrayHandler[parm->p[0].val.ev_long].array;
	ah->rows = parm->p[1].val.ev_long;
	ah->cols = parm->p[2].val.ev_long;
	ah->array = new double[ah->rows*ah->cols];
}

void FAR CloseArray(ParamBlk FAR *parm)
{	delete ArrayHandler[parm->p[0].val.ev_long].array;
	ArrayHandler[parm->p[0].val.ev_long].array = NULL;
}

void FAR SetArrayElement(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	ah = &ArrayHandler[parm->p[0].val.ev_long];
	ah->array[(parm->p[1].val.ev_long-1) * ah->cols + parm->p[2].val.ev_long-1] = parm->p[3].val.ev_real;
}

void FAR GetArrayElement(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	ah = &ArrayHandler[parm->p[0].val.ev_long];
	_RetFloat(ah->array[(parm->p[1].val.ev_long-1) * ah->cols + parm->p[2].val.ev_long-1],20,12);
}

void FAR GetArrayRows(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	ah = &ArrayHandler[parm->p[0].val.ev_long];
	_RetInt(ah->rows,10);
}

void FAR GetArrayCols(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	ah = &ArrayHandler[parm->p[0].val.ev_long];
	_RetInt(ah->cols,10);
}

void FAR swaprow(AHandle FAR *ah, long row1, long row2)
{	double swap;
	double FAR *pos1;
	double FAR *pos2;
	double FAR *stop;
	long cols;
	
	cols = ah->cols;
	pos1 = ah->array + row1 * cols;
	pos2 = ah->array + row2 * cols;
	stop = pos1+cols-1;
	do
	{	swap = *pos1;
		*pos1 = *pos2;
		*pos2 = swap;
		if (pos1 != stop)
		{	pos1++;
			pos2++;
		}
		else
		{	break;
		}
	}
	while (true);
}

long FAR pivotasc(AHandle FAR *ah, long top, long bot, long col)
{	long t, b, mid, cols;
	double pivot;
	double FAR *array;
	
	cols = ah->cols;
	array = ah->array;
	mid = top+(bot-top)/2;
	if (array[mid*cols+col] < array[top*cols+col]) swaprow(ah, top, mid);
	if (array[bot*cols+col] < array[top*cols+col]) swaprow(ah, top, bot);
	if (array[bot*cols+col] < array[mid*cols+col]) swaprow(ah, mid, bot);
	pivot = array[mid*cols+col];
	t = top-1;
	b = bot+1;
	while (1)
	{	do { t++; } while (array[t*cols+col] < pivot);
		do { b--; } while (array[b*cols+col] > pivot);
		if (t >= b) return b;
		swaprow(ah, t, b);
	}
}

void FAR quicksortasc(AHandle FAR *ah, long top, long bottom, long col)
{	if (top >= bottom) return;
	long pivot = pivotasc(ah, top, bottom, col);
	quicksortasc(ah, top, pivot, col);
	quicksortasc(ah, pivot + 1, bottom, col);
	
}

void FAR SortArrayAsc(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	ah = &ArrayHandler[parm->p[0].val.ev_long];
	quicksortasc(ah, 0, parm->p[2].val.ev_long-1, parm->p[1].val.ev_long-1);
}

long FAR pivotdesc(AHandle FAR *ah, long top, long bot, long col)
{	long t, b, mid, cols;
	double pivot;
	double FAR *array;
	
	cols = ah->cols;
	array = ah->array;
	mid = top+(bot-top)/2;
	if (array[mid*cols+col] > array[top*cols+col]) swaprow(ah, top, mid);
	if (array[bot*cols+col] > array[top*cols+col]) swaprow(ah, top, bot);
	if (array[bot*cols+col] > array[mid*cols+col]) swaprow(ah, mid, bot);
	pivot = array[mid*cols+col];
	t = top-1;
	b = bot+1;
	while (1)
	{	do { t++; } while (array[t*cols+col] > pivot);
		do { b--; } while (array[b*cols+col] < pivot);
		if (t >= b) return b;
		swaprow(ah, t, b);
	}
}

void FAR quicksortdesc(AHandle FAR *ah, long top, long bottom, long col)
{	if (top >= bottom) return;
	long pivot = pivotdesc(ah, top, bottom, col);
	quicksortdesc(ah, top, pivot, col);
	quicksortdesc(ah, pivot+1, bottom, col);
}

void FAR SortArrayDesc(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	ah = &ArrayHandler[parm->p[0].val.ev_long];
	quicksortdesc(ah, 0, parm->p[2].val.ev_long-1, parm->p[1].val.ev_long-1);
}

void FAR dutchpivotasc(AHandle FAR *ah, long *topi, long *boti, long col)
{	long top, bot, mid, cols;
	double pivot, item;
	double FAR *array;
	
	top = *topi;
	bot = *boti;
	cols = ah->cols;
	array = ah->array;
	mid = top+(bot-top)/2;
	if (array[mid*cols+col] < array[top*cols+col]) swaprow(ah, top, mid);
	if (array[bot*cols+col] < array[top*cols+col]) swaprow(ah, top, bot);
	if (array[bot*cols+col] < array[mid*cols+col]) swaprow(ah, mid, bot);
	pivot = array[mid*cols+col];
	mid = top;
	while (mid <= bot)
	{	item = array[mid*cols+col];
		if (item < pivot)
		{	swaprow(ah, mid, top);
			top++;
			mid++;
		}
		else if (item > pivot)
		{	swaprow(ah, mid, bot);
			bot--;
		}
		else mid++;
	}
	*topi = top-1;
	*boti = bot+1;
}
			
void FAR dutchsortasc(AHandle FAR *ah, long top, long bottom, long col)
{	if (top >= bottom) return;
	long t = top;
	long b = bottom;
	dutchpivotasc(ah, &t, &b, col);
	dutchsortasc(ah, top, t, col);
	dutchsortasc(ah, b, bottom, col);
}

void FAR DutchSortArrayAsc(ParamBlk FAR *parm) // Quicksort with 3-way partioning (Dutch National Flag)
{	AHandle FAR *ah;
	ah = &ArrayHandler[parm->p[0].val.ev_long];
	dutchsortasc(ah, 0, parm->p[2].val.ev_long-1, parm->p[1].val.ev_long-1);
}

void FAR dutchpivotdesc(AHandle FAR *ah, long *topi, long *boti, long col)
{	long top, bot, mid, cols;
	double pivot, item;
	double FAR *array;
	
	top = *topi;
	bot = *boti;
	cols = ah->cols;
	array = ah->array;
	mid = top+(bot-top)/2;
	if (array[mid*cols+col] < array[top*cols+col]) swaprow(ah, top, mid);
	if (array[bot*cols+col] < array[top*cols+col]) swaprow(ah, top, bot);
	if (array[bot*cols+col] < array[mid*cols+col]) swaprow(ah, mid, bot);
	pivot = array[mid*cols+col];
	mid = top;
	while (mid <= bot)
	{	item = array[mid*cols+col];
		if (item > pivot)
		{	swaprow(ah, mid, top);
			top++;
			mid++;
		}
		else if (item < pivot)
		{	swaprow(ah, mid, bot);
			bot--;
		}
		else mid++;
	}
	*topi = top-1;
	*boti = bot+1;
}
			
void FAR dutchsortdesc(AHandle FAR *ah, long top, long bottom, long col)
{	if (top >= bottom) return;
	long t = top;
	long b = bottom;
	dutchpivotdesc(ah, &t, &b, col);
	dutchsortdesc(ah, top, t, col);
	dutchsortdesc(ah, b, bottom, col);
}

void FAR DutchSortArraydesc(ParamBlk FAR *parm) // Quicksort with 3-way partioning (Dutch National Flag)
{	AHandle FAR *ah;
	ah = &ArrayHandler[parm->p[0].val.ev_long];
	dutchsortdesc(ah, 0, parm->p[2].val.ev_long-1, parm->p[1].val.ev_long-1);
}

void FAR ApplyNoise(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	double FAR *array, noise, filter, rounder;
	long cols, col, stop, ind;

	srand(time(NULL));
	ah = &ArrayHandler[parm->p[0].val.ev_long];
	array = ah->array;
	cols = ah->cols;
	col = parm->p[1].val.ev_long - 1;
	stop = (parm->p[2].val.ev_long - 1) * cols + col;
	filter = pow(10, (double) parm->p[3].val.ev_long - 1); 
	noise = 1/filter;
	rounder = noise * 0.5;
	for (ind = col; ind <= stop; ind += cols)
	{	if (array[ind] >= 0)
		{	array[ind] = (floor((array[ind] + rounder) * filter) + (double) rand() / RAND_MAX * 0.9) * noise;
		}
		else
		{	array[ind] = (ceil((array[ind] - rounder) * filter) - (double) rand() / RAND_MAX * 0.9) * noise;
		}
	}
}
	
void FAR FilterNoise(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	double FAR *array, filter, noise;
	long cols, col, stop, ind;

	ah = &ArrayHandler[parm->p[0].val.ev_long];
	array = ah->array;
	cols = ah->cols;
	col = parm->p[1].val.ev_long - 1;
	stop = (parm->p[2].val.ev_long - 1) * cols + col;
	filter = pow(10, (double) parm->p[3].val.ev_long - 1);
	noise = 1/filter;
	for (ind = col; ind <= stop; ind += cols)
	{	if (array[ind] >= 0)
		{	array[ind] = floor(array[ind] * filter) * noise;
		}
		else
		{	array[ind] = ceil(array[ind] * filter) * noise;
		}
	}
}

double FAR lrcpd(char FAR *a, char FAR *b, long alen, long blen, long scope) // least relative character position delta
{	char achr;
	int left, right;
	long bpivot, i, j, bpos;
	double amax, bmax, score, arel, cor, delta;

	if (alen <= 0 && blen <= 0) return 1;
	if (alen <= 0 || blen <= 0) return 0;
	if (alen <= 1) 
	{	amax = 1;
	}
	else
	{	amax = (double) alen - 1;
	}
	if (blen <= 1) 
	{	bmax = 1;
	}
	else
	{	bmax = (double) blen - 1;
	}
	if (scope < 0 || scope >= bmax)
	{	scope = (long) bmax;
		cor = 1;
	}
	else
	{	cor = bmax / (scope + 1);
	}
	score = 0;
	for (i = 0; i < alen; i++)
	{	achr = a[i];
		arel = i / amax;
		bpivot = (long) (arel * bmax + 0.5);
		if (b[bpivot] == achr)
		{	delta = (bpivot / bmax - arel) * cor;
			if (delta < 0) delta = -delta;
			score += 1 - delta;
		}
		else
		{	left = 1;
			right = 1;
			for (j = 1; j <= scope && (left || right); j++)
			{	if (right)
				{	bpos = bpivot + j;
					if (bpos >= blen)
					{	right = 0;
					}
					else
					{	if (b[bpos] == achr)
						{	score += 1 - (bpos / bmax - arel) * cor;
							break;
						}
					}
				}
				if (left)
				{	bpos = bpivot - j;
					if (bpos < 0)
					{	left = 0;
					}
					else
					{	if (b[bpos] == achr)
						{	score += 1 - (arel - bpos / bmax) * cor;
							break;
						}
					}
				}
			}
		}
	}
	return score / (double) alen;
}

void FAR Compare(ParamBlk FAR *parm)
{	char FAR *a, *b;
	long alen, blen, scope;
	double score1, score2;

	alen = parm->p[0].val.ev_length;
	blen = parm->p[1].val.ev_length;
	scope = parm->p[2].val.ev_long;
	_HLock(parm->p[0].val.ev_handle);
	_HLock(parm->p[1].val.ev_handle);
	a = (char FAR *) _HandToPtr(parm->p[0].val.ev_handle);
	b = (char FAR *) _HandToPtr(parm->p[1].val.ev_handle);
	score1 = lrcpd(a, b, alen, blen, scope);
	score2 = lrcpd(b, a, blen, alen, scope);
	_HUnLock(parm->p[0].val.ev_handle);
	_HUnLock(parm->p[1].val.ev_handle);
	if (score1 < score2)
	{	_RetFloat(score1,8,6);
	}
	else
	{	_RetFloat(score2,8,6);
	}
}

void FAR Invert(ParamBlk FAR *parm)
{	char FAR *str;
	long len, i;

	len = parm->p[0].val.ev_length;
	if (len >= BUFFERSIZE)
	{	len = BUFFERSIZE-1;
	}
	_HLock(parm->p[0].val.ev_handle);
	str = (char FAR *) _HandToPtr(parm->p[0].val.ev_handle);
	for (i=0; i < len; i++) buffer[i] = 255-str[i];
	buffer[i] = '\0';
	_HUnLock(parm->p[0].val.ev_handle);
	_RetChar(buffer);
}

void FAR CollectSumArray(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	double FAR *array;
	long cols, stop, idCol, sumCol, ind;
	double sum, oldId, id, collected;
	
	ah = &ArrayHandler[parm->p[0].val.ev_long];
	array = ah->array;
	cols = ah->cols;
	stop = (parm->p[1].val.ev_long - 1) * cols;
	idCol = parm->p[2].val.ev_long - 1;
	sumCol = parm->p[3].val.ev_long - 1;
	collected = parm->p[4].val.ev_real;
	oldId = array[idCol];
	sum = array[sumCol];
	array[sumCol] = collected;
	for (ind = cols; ind <= stop; ind += cols)
	{	id = array[ind+idCol];
		if (id == oldId)
		{	sum += array[ind + sumCol];
		}
		else
		{	oldId = id;
			array[ind - cols + sumCol] = sum;
			sum = array[ind+sumCol];
		}
		array[ind + sumCol] = collected;
	}
	array[stop + sumCol] = sum;
}

void FAR LimitDescArray(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	double FAR *array;
	long cols, top, bottom, ind, limitCol, dir;
	double limit;

	ah = &ArrayHandler[parm->p[0].val.ev_long];
	array = ah->array;
	cols = ah->cols;
	limit = parm->p[1].val.ev_real;
	limitCol = parm->p[4].val.ev_long - 1;
	top = (parm->p[2].val.ev_long - 1) * cols + limitCol;
	bottom = (parm->p[3].val.ev_long - 1) * cols + limitCol;
	dir = parm->p[5].val.ev_long;
	if (dir >= 0)
	{	for (ind = top; ind <= bottom; ind += cols)
		{	if (array[ind] < limit) break;
		}
		_RetInt((ind - limitCol) / cols, 10);
	}
	else
	{	for (ind = bottom; ind >= top; ind -= cols)
		{	if (array[ind] > limit) break;
		}
		_RetInt((ind - limitCol) / cols + 1, 10);
	}

}	


void FAR BinarySearchAscArray(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	double FAR *array;
	long cols, top, bottom, keycol, ind;
	double key, element;

	ah = &ArrayHandler[parm->p[0].val.ev_long];
	array = ah->array;
	cols = ah->cols;
	key = parm->p[1].val.ev_real;
	top = parm->p[2].val.ev_long - 1;
	bottom = parm->p[3].val.ev_long - 1;
	keycol = parm->p[4].val.ev_long - 1;
	while (top <= bottom)
	{	ind = (top + bottom) / 2;
		element = array[ind * cols + keycol];
		if (element == key)
		{	_RetInt(ind + 1,10);
			return;
		}
		if (key > element)
		{	top = ind + 1;
		}
		else
		{	bottom = ind - 1;
		}
	}
	_RetInt(-top - 1,10);
	return;
}


void FAR BinarySearchDescArray(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	double FAR *array;
	long cols, top, bottom, keycol, ind;
	double key, element;

	ah = &ArrayHandler[parm->p[0].val.ev_long];
	array = ah->array;
	cols = ah->cols;
	key = parm->p[1].val.ev_real;
	top = parm->p[2].val.ev_long - 1;
	bottom = parm->p[3].val.ev_long - 1;
	keycol = parm->p[4].val.ev_long - 1;
	while (top <= bottom)
	{	ind = (top + bottom) / 2;
		element = array[ind * cols + keycol];
		if (element == key)
		{	_RetInt(ind + 1,10);
			return;
		}
		if (key > element)
		{	bottom = ind - 1;
		}
		else
		{	top = ind + 1;
		}
	}
	_RetInt(-top - 1,10);
	return;
}

void FAR FillArray(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	double FAR *array;
	long cols, start, end, valcol;
	double val;

	ah = &ArrayHandler[parm->p[0].val.ev_long];
	array = ah->array;
	cols = ah->cols;
	val = parm->p[1].val.ev_real;
	start = parm->p[2].val.ev_long - 1;
	end = start + parm->p[3].val.ev_long - 1;
	if (end >= ah->rows) end = ah->rows - 1;
	valcol = parm->p[4].val.ev_long - 1;
	start = start * cols + valcol;
	end = end * cols + valcol;
	for (; start <= end; start += cols)
	{	array[start] = val;
	}
	_RetInt((end - valcol) / cols + 1, 10);
}

// Copies rectangular regions between arrays or within the same array
// para: source_array_handle, target_array_handle, source_start_row, source_start_col, target_start_row, target_start_col, number_of_rows, number_of_cols
void FAR CopyArray(ParamBlk FAR *parm)
{	AHandle FAR *ah, *bh;
	double FAR *array, *brray;
	long arow, acol, brow, bcol, rows, cols;
	long acols, bcols, astart, bstart, apos, bpos, r, c;
	

	ah = &ArrayHandler[parm->p[0].val.ev_long];
	bh = &ArrayHandler[parm->p[1].val.ev_long];
	arow = parm->p[2].val.ev_long - 1;
	acol = parm->p[3].val.ev_long - 1;
	brow = parm->p[4].val.ev_long - 1;
	bcol = parm->p[5].val.ev_long - 1;
	rows = parm->p[6].val.ev_long;
	cols = parm->p[7].val.ev_long;
	array = ah->array;
	brray = bh->array;
	acols = ah->cols;
	bcols = bh->cols;
	if (rows <= 0)
	{	rows = ah->rows;
	}
	if (cols <= 0)
	{	cols = ah->cols;
	}
	if (arow + rows > ah->rows)
	{	rows = ah->rows - arow;
	}
	if (brow + rows > bh->rows)
	{	rows = bh->rows - brow;
	}
	if (acol + cols > acols)
	{	cols = acols - acol;
	}
	if (bcol + cols > bcols)
	{	cols = bcols - bcol;
	}
	astart = arow * acols;
	bstart = brow * bcols;
	for (r = 0; r < rows; r++)
	{	apos = astart + r * acols + acol;
		bpos = bstart + r * bcols + bcol;
		for (c = 0; c < cols; c++)
		{	brray[bpos + c] = array[apos + c];
		}
	}
}

void FAR CopyTable(ParamBlk FAR *parm)
{	Locator field;
	AHandle FAR *ah;
	double FAR *array;
	long cols, start, end, valcol;
	short table;
	NTI nti;
	char FAR *name;
	Value val;


	ah = &ArrayHandler[parm->p[0].val.ev_long];
	array = ah->array;
	cols = ah->cols;
	table = (short) parm->p[1].val.ev_long;
	if (table <= 0)
	{	table = -1;
	}
	if (!_SetHandSize(parm->p[2].val.ev_handle,parm->p[2].val.ev_length+1))
	{	_Error(182); // Insufficient memory
	}
	_HLock(parm->p[2].val.ev_handle);
	name = (char FAR *) _HandToPtr(parm->p[2].val.ev_handle);
	name[parm->p[2].val.ev_length] = '\0';
	nti = _NameTableIndex(name);
	_HUnLock(parm->p[2].val.ev_handle);
	if (nti == -1 || ! _FindVar(nti,table,&field))
	{	_UserError("Invalid field name.");
	}
	start = parm->p[3].val.ev_long - 1;
	end = start + parm->p[4].val.ev_long - 1;
	valcol = parm->p[5].val.ev_long - 1;
	if (end >= ah->rows) end = ah->rows - 1;
	start = start * cols + valcol;
	end = end * cols + valcol;
	_Load(&field,&val);
	if (val.ev_type == 'I')
	{	if (table > 0)
		{	for (; start <= end; start += cols)
			{	array[start] = (double) val.ev_long;
				if (_DBSkip(table,1) < 0)
				{	start += cols;
					break;
				}
				_Load(&field,&val);
			}
		}
		else
		{	for (; start <= end; start += cols) array[start] = (double) val.ev_long;
		}
	}
	else
	{	if (table > 0)
		{	for (; start <= end; start += cols)
			{	array[start] = val.ev_real;
				if (_DBSkip(table,1) < 0)
				{	start += cols;
					break;
				}
				_Load(&field,&val);
			}
		}
		else
		{	for (; start <= end; start += cols) array[start] = val.ev_real;
		}
	}
	_RetInt((start - valcol) / cols, 10);
}

void FAR CopyVector(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	double FAR *array;
	FCHAN fchan;
	long cols, fstart, start, asize, valcol, alen, rlen;
	int i;
	
	ah = &ArrayHandler[parm->p[0].val.ev_long];
	array = ah->array;
	cols = ah->cols;
	fchan = parm->p[1].val.ev_long;
	fstart = parm->p[2].val.ev_long;
	start = parm->p[3].val.ev_long - 1;
	asize = parm->p[4].val.ev_long;
	valcol = parm->p[5].val.ev_long - 1;
	if (start + asize - 1 >= ah->rows) asize = ah->rows - start;
	start = start * cols + valcol;
	_FSeek(fchan, 328 + (fstart - 1) * 5, FS_FROMBOF);
	while (asize > 0)
	{	if (asize > 13107)
		{	alen = 65535;
			asize -= 13107;
		}
		else
		{	alen = asize*5;
			asize = 0;
		}
		rlen = _FRead(fchan, buffer, alen);
		if (rlen != alen)
		{	asize = 0;
		}
		for (i = 1; i < rlen; i += 5)
		{	array[start] = *((long *) &buffer[i]);
			start += cols;
		}
	
	}
	_RetInt((start - valcol) / cols, 10);
}

void FAR ImportArray(ParamBlk FAR *parm)
{	AHandle FAR *ah;
	Locator loc;
	double FAR *array;
	long index, skip;
	USHORT irows, icols;
	Value val;

	loc = parm->p[0].loc;
	ah = &ArrayHandler[parm->p[1].val.ev_long];
	array = ah->array;
	irows = (USHORT) parm->p[2].val.ev_long;
	icols = (USHORT) parm->p[3].val.ev_long;
	if (irows > ah->rows) irows = (USHORT) ah->rows;
	if (icols > ah->cols) icols = (USHORT) ah->cols;
	skip = ah->cols - icols;
	loc.l_subs = 2;
	index = 0;
	for (loc.l_sub1 = 1; loc.l_sub1 <= irows; loc.l_sub1++)
	{	for (loc.l_sub2 = 1; loc.l_sub2 <= icols; loc.l_sub2++)
		{	_Load(&loc, &val);
			if (val.ev_type == 'I') array[index] = (double) val.ev_long;
			else array[index] = val.ev_real;
			index++;
		}
		index += skip; 
	}
}

void FAR BinarySearchEngine(ParamBlk FAR *parm)
{	AHandle FAR *searched, *found;
	double FAR *searchedArray, *foundArray;
	long searchedCols, foundCols;
	FCHAN fchan;
	Locator index;
	short ri;
	double limit, sum, share, shareLimit;
	long foundRows, searchedRows, start, max;
	int darwin, buffering;
	long i, j, end, top, bottom, pivot, item, tar, size, offset, steps;
	NTI nti;
	Value val;
	char *buf;
	
	searched = &ArrayHandler[parm->p[0].val.ev_long];
	found = &ArrayHandler[parm->p[1].val.ev_long];
	searchedCols = searched->cols;
	foundCols = found->cols;
	searchedArray = searched->array;
	foundArray = found->array;
	searchedRows = (parm->p[2].val.ev_long - 1) * searchedCols;
	foundRows = (parm->p[3].val.ev_long - 1) * foundCols;
	start = (parm->p[4].val.ev_long - 1) * foundCols;
	limit = parm->p[5].val.ev_real;
	darwin = parm->p[6].val.ev_length;
	ri = (short) parm->p[7].val.ev_long;
	fchan = parm->p[8].val.ev_long;
	buffering = parm->p[9].val.ev_length;
	steps = foundRows-start+1;
	if (steps <= 0) buffering = 0;
	max = start;
	nti = _NameTableIndex("index");
	_FindVar(nti, ri, &index);
	for (i = 0; i <= searchedRows; i += searchedCols)
	{	if (searchedArray[i+5] <= 0) continue;
		share = searchedArray[i+3];
		shareLimit = searchedArray[i+2];
		_DBRead(ri, (long) searchedArray[i]);
		_Load(&index,&val);
		top = (long) val.ev_real;
		_DBSkip(ri,1);
		_Load(&index,&val);
		end = (long) val.ev_real;
		end--;
		if (top > end)
		{	continue;
		}
		size = end-top+1;
		if (buffering && size <= 5000000 && ((double) size/steps) <= 1000)
		{	_FSeek(fchan, 328+(top-1)*5, FS_FROMBOF);
			buf = buffer;
			while (size > 0)
			{	if (size > 13107)
				{	_FRead(fchan, buf, 65535 );
					buf += 65535;
					size -= 13107;
				}
				else
				{	_FRead(fchan, buf, size*5);
					size = 0;
				}
			}
			offset = top;
			for (j = start; j <= foundRows; j += foundCols)
			{	sum = foundArray[j+1];
				if (sum+shareLimit < limit)	continue;
				item = (long) foundArray[j];
				bottom = end;
				while (top <= bottom)
				{	pivot = (long) (bottom+top)/2;
					tar	= *((long *) &buffer[(pivot-offset)*5+1]);
					if (tar == item)
					{	top++;
						sum = sum+share;
						if (j > max)
						{	max = j;
						}
						break;
					}
					if (item < tar)
					{	bottom = pivot-1;
					}
					else
					{	top = pivot+1;
					}
				}
				foundArray[j+1] = sum;
				if (darwin && sum > limit)
				{	limit = sum;
				}
				if (top > end)
				{	break;
				}							
			}
		}
		else
		{	for (j = start; j <= foundRows; j += foundCols)
			{	sum = foundArray[j+1];
				if (sum+shareLimit < limit)	continue;
				item = (long) foundArray[j];
				bottom = end;
				while (top <= bottom)
				{	pivot = (long) (bottom+top)/2;
					_FSeek(fchan, 329+(pivot-1)*5, FS_FROMBOF);
					_FRead(fchan, buffer, 4);
					tar	= *((long *) &buffer);
					if (tar == item)
					{	top++;
						sum = sum+share;
						if (j > max)
						{	max = j;
						}
						break;
					}
					if (item < tar)
					{	bottom = pivot-1;
					}
					else
					{	top = pivot+1;
					}
				}
				foundArray[j+1] = sum;
				if (darwin && sum > limit)
				{	limit = sum;
				}
				if (top > end)
				{	break;
				}							
			}
		}
	}
	if (max > start)
	{	max += foundCols;
	}
	_RetInt(max / foundCols + 1,10);
}

void FAR InternalBinarySearchAscArray(ParamBlk FAR *parm)
{	Locator array;
	long top, bottom;
	double key, element;
	Value val;

	array = parm->p[0].loc;
	if (_ALen(array.l_NTI, AL_SUBSCRIPT2) > 0)
	{	array.l_subs = 2;
	}
	else
	{	array.l_subs = 1;
	}
	key = parm->p[1].val.ev_real;
	top = parm->p[2].val.ev_long;
	bottom = parm->p[3].val.ev_long;
	array.l_sub2 = (USHORT) parm->p[4].val.ev_long;
	while (top <= bottom)
	{	array.l_sub1 = (USHORT) ((long) (top+bottom)/2);
		_Load(&array,&val);
		if (val.ev_type == 'I') element = (double) val.ev_long;
		else element = val.ev_real;
		if (element == key)
		{	_RetInt(array.l_sub1,10);
			return;
		}
		if (key > element)
		{	top = (long) array.l_sub1+1;
		}
		else
		{	bottom = (long) array.l_sub1-1;
		}
	}
	_RetInt(-top,10);
	return;
}

void FAR InternalBinarySearchDescArray(ParamBlk FAR *parm)
{	Locator array;
	long top, bottom;
	double key, element;
	Value val;

	array = parm->p[0].loc;
	if (_ALen(array.l_NTI, AL_SUBSCRIPT2) > 0)
	{	array.l_subs = 2;
	}
	else
	{	array.l_subs = 1;
	}
	key = parm->p[1].val.ev_real;
	top = parm->p[2].val.ev_long;
	bottom = parm->p[3].val.ev_long;
	array.l_sub2 = (USHORT) parm->p[4].val.ev_long;
	while (top <= bottom)
	{	array.l_sub1 = (USHORT) ((long) (top+bottom)/2);
		_Load(&array,&val);
		if (val.ev_type == 'I') element = (double) val.ev_long;
		else element = val.ev_real;
		if (element == key)
		{	_RetInt(array.l_sub1,10);
			return;
		}
		if (key > element)
		{	bottom = (long) array.l_sub1-1;
		}
		else
		{	top = (long) array.l_sub1+1;
		}
	}
	_RetInt(-top,10);
	return;
}

FoxInfo myFoxInfo[] = 
{
	{"FoxproVersion", (FPFI) FoxproVersion, 0, ""},
	{"FileOpenRead", (FPFI) FileOpenRead, 2, "IC"},
	{"FileOpenWrite", (FPFI) FileOpenWrite, 2, "IC"},
	{"FileOpenAppend", (FPFI) FileOpenAppend, 2, "IC"},
	{"FileClose", (FPFI) FileClose, 1, "I"},
	{"FileRewind", (FPFI) FileRewind, 1, "I"},
	{"FileEOF", (FPFI) FileEOF, 1, "I"},
	{"FileRead", (FPFI) FileRead, 2, "II"},
	{"FileReadCRLF", (FPFI) FileReadCRLF, 1, "I"},
	{"FileReadLF", (FPFI) FileReadLF, 1, "I"},
	{"FileSize", (FPFI) FileSize, 1, "I"},
	{"FilePos", (FPFI) FilePos, 1, "I"},
	{"FileWrite", (FPFI) FileWrite, 2, "IC"},
	{"FileWriteCRLF", (FPFI) FileWriteCRLF, 2, "IC"},
	{"FileWriteLF", (FPFI) FileWriteLF, 2, "IC"},
	{"FileGo", (FPFI) FileGo, 2, "IN"},
	{"OpenArray", (FPFI) OpenArray, 3, "III"},
	{"CloseArray", (FPFI) CloseArray, 1, "I"},
	{"SetArrayElement", (FPFI) SetArrayElement, 4, "IIIN"},
	{"GetArrayElement", (FPFI) GetArrayElement, 3, "III"},
	{"GetArrayRows", (FPFI) GetArrayRows, 1, "I"},
	{"GetArrayCols", (FPFI) GetArrayCols, 1, "I"},
	{"SortArrayAsc", (FPFI) SortArrayAsc, 3, "III"},
	{"SortArrayDesc", (FPFI) SortArrayDesc, 3, "III"},
	{"DutchSortArrayAsc", (FPFI) DutchSortArrayAsc, 3, "III"},
	{"DutchSortArrayDesc", (FPFI) DutchSortArrayAsc, 3, "III"},
	{"ApplyNoise", (FPFI) ApplyNoise, 4, "IIII"},
	{"FilterNoise", (FPFI) FilterNoise, 4, "IIII"},
	{"Compare", (FPFI) Compare, 3, "CCI"},
	{"Invert", (FPFI) Invert, 1, "C"},
	{"CollectSumArray", (FPFI) CollectSumArray, 5, "IIIIN"},
	{"LimitDescArray", (FPFI) LimitDescArray, 6, "INIIII"},
	{"BinarySearchAscArray", (FPFI) BinarySearchAscArray, 5, "INIII"},
	{"BinarySearchDescArray", (FPFI) BinarySearchDescArray, 5, "INIII"},
	{"FillArray", (FPFI) FillArray, 5, "INIII"},
	{"CopyArray", (FPFI) CopyArray, 8, "IIIIIIII"},
	{"CopyTable", (FPFI) CopyTable, 6, "IICIII"},
	{"CopyVector", (FPFI) CopyVector, 6, "IIIIII"},
	{"ImportArray", (FPFI) ImportArray, 4, "RIII"},
	{"BinarySearchEngine", (FPFI) BinarySearchEngine, 10, "IIIIINLIIL"},
	{"InternalBinarySearchAscArray", (FPFI) InternalBinarySearchAscArray, 5, "RNIII"},
	{"InternalBinarySearchDescArray", (FPFI) InternalBinarySearchDescArray, 5, "RNIII"},
};


#ifdef __cplusplus
extern "C"
#endif
FoxTable _FoxTable = {
(FoxTable *)0, sizeof(myFoxInfo)/sizeof(FoxInfo), myFoxInfo
};
