#ifndef TAGDICT_H
#define TAGDICT_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef unsigned long hashkey_t ; // 32 bits

typedef struct tagdict_s *PTagDict;

//==============================================================
//
//
//
//==============================================================

#define MAX_KEY 255

typedef struct s_KeyNode {
	struct s_KeyNode *next;
    hashkey_t  hashkey;
	char       key[MAX_KEY+1];
} KeyNode;

#define KeyList_SIG 0x010A9842

typedef struct {
	int sig;
	KeyNode *first;
    //int len; // Arthur 18/10/2021: usado para o teste de colisao
} KeyList;

#define DICT_SIZE 100403

typedef struct tagdict_s {
    KeyList content[DICT_SIZE];
} TagDict;


PTagDict dict_create(void);
void     dict_destroy(PTagDict ptd);

int dict_insert_if_new(PTagDict ptd, char *key);

void     dict_print(PTagDict ptd);

#endif  /* TAGDICT_H */
