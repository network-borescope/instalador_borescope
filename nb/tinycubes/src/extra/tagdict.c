#include "tagdict.h"



static void freeKeyList(KeyList *pkl) {
	if (!pkl)  return; 
	KeyNode *pkn, *next;
    for (pkn = pkl->first; pkn; pkn = next) {
		next = pkn->next;
		free(pkn);
	}
}


//
//
//
static void printKeyList(KeyList *l) {
	KeyNode *pi = l->first;
	for (KeyNode *p = l->first; p; p = p->next) {
		printf("%s ", p->key);
	}
	printf("\n");
}


//==============================================================
//
//
//
//==============================================================

//
//
//
static hashkey_t hash_function(const uint8_t* key, size_t length) {
//static int jenkins_one_at_a_time_hash(const uint8_t* key, size_t length) {

    size_t i = 0;
    hashkey_t hash = 0;
    while (i != length) {
        hash += key[i++];
        hash += hash << 10;
        hash ^= hash >> 6;
    }
    hash += hash << 3;
    hash ^= hash >> 11;
    hash += hash << 15;
    // convertendo para hashkey do dict
    //long long int a = (long long int)hash;
    //int hashKey = a % DICT_SIZE;
    //return hashKey;
    return hash;
}

//==============================================================
//
//
//
//==============================================================

//
//
//
PTagDict dict_create() {
    TagDict *ptd = (TagDict*) calloc(1, sizeof(TagDict));
    return ptd;
}

//
//
//
void dict_destroy(PTagDict ptd) {
    for(int i = 0; i < DICT_SIZE; i++) {
        freeKeyList(&ptd->content[i]);
    }
    free(ptd);
}

//
//
//
int dict_insert_if_new(PTagDict ptd, char *key) {

    int len = strlen(key);
    hashkey_t hashkey = hash_function(key, len);

    int pos = hashkey % DICT_SIZE;
    KeyList *pkl = &ptd->content[pos];

    // search for the key
    KeyNode *pkn;

	for (pkn = pkl->first; pkn; pkn = pkn->next) {
        if (pkn->hashkey != hashkey) continue;
		if (strcmp(pkn->key, key) == 0) return 0; 
	}

    // alloc and fill the new node
    pkn = malloc(sizeof(KeyNode));
    pkn->hashkey = hashkey;
    strncpy(pkn->key, key, len);

    // prepend the new node
    pkn->next = pkl->first;
	pkl->first = pkn;
    //pkl->len++; // Arthur 18/10/2021: usado para o teste de colisao
   
    return 1;
}


//
//
//
void dict_print(PTagDict ptd) {
    for(int i = 0; i < DICT_SIZE; i++) {
        printf("Dict hash %d: ", i);
        printKeyList(&ptd->content[i]);
        printf("\n");
    }
}
