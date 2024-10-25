
%token	<string_val> WORD

%token 	NOTOKEN LPARENT RPARENT LBRACE RBRACE LCURLY RCURLY COMA SEMICOLON EQUAL STRING_CONST LONG LONGSTAR VOID CHARSTAR CHARSTARSTAR INTEGER_CONST AMPERSAND OROR ANDAND EQUALEQUAL NOTEQUAL LESS GREAT LESSEQUAL GREATEQUAL PLUS MINUS TIMES DIVIDE PERCENT IF ELSE WHILE DO FOR CONTINUE BREAK RETURN

%union	{
	char   *string_val;
	int nargs;
	int my_nlabel;
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
	int yylex();
	int yyerror(const char * s);

	extern int line_number;
	const char * input_file;
	char * asm_file;
	FILE * fasm;

#define MAX_ARGS 5
	int nargs;
	char * args_table[MAX_ARGS];

#define MAX_GLOBALS 100
	int nglobals = 0;
	char * global_vars_table[MAX_GLOBALS];

	int global_vars_type[MAX_GLOBALS];

#define MAX_LOCALS 16
	int nlocals = 0;
	char * local_vars_table[MAX_LOCALS];
	int local_vars_type[MAX_LOCALS];

#define MAX_STRINGS 100
	int nstrings = 0;
	char * string_table[MAX_STRINGS];

	char *regStk[]=      { "rbx", "r10", "r13", "r14", "r15"};
	char nregStk = sizeof(regStk)/sizeof(char*);
	char *byteRegisters[] = { "bl", "r10b", "r13b", "r14b", "r15b"};

	char *regArgs[]= { "rdi", "rsi", "rdx", "rcx", "r8", "r9"};
	char nregArgs = sizeof(regArgs)/sizeof(char*);




	int if_label = 0;

	int var_type = -1;

	int top = 0;

	int nargs =0;

	int nlabel = 0;






	%}

	%%

	goal:	program
	;

program :
function_or_var_list;

function_or_var_list:
function_or_var_list function
| function_or_var_list global_var
| /*empty */
;

function:
var_type WORD
{
	fprintf(fasm, "\t.text\n");
	fprintf(fasm, ".globl %s\n", $2);
	fprintf(fasm, "%s:\n", $2);

	fprintf(fasm, "# Save registers\n");
	fprintf(fasm, "\tpushq %%rbx\n");
	fprintf(fasm, "\tpushq %%r10\n");
	fprintf(fasm, "\tpushq %%r13\n");
	fprintf(fasm, "\tpushq %%r14\n");
	fprintf(fasm, "\tpushq %%r15\n");
	fprintf(fasm, "\tsubq $%d,%%rsp\n", 8*MAX_LOCALS); 
	nlocals = 0;
	top = 0; 
}
LPARENT arguments RPARENT 
{
	int i;
	for (i=0; i<nlocals;i++) {
		fprintf(fasm, "\tmovq %%%s,%d(%%rsp)\n",
				regArgs[i], 8*(MAX_LOCALS-i) );
	}
}
compound_statement
{
	fprintf(fasm, "\taddq $%d,%%rsp\n", 8*MAX_LOCALS); 
	fprintf(fasm, "# Restore registers\n");
	fprintf(fasm, "\tpopq %%r15\n");
	fprintf(fasm, "\tpopq %%r14\n");
	fprintf(fasm, "\tpopq %%r13\n");
	fprintf(fasm, "\tpopq %%r10\n");
	fprintf(fasm, "\tpopq %%rbx\n");
	fprintf(fasm, "\tret\n");
}
;

arg_list:
arg
| arg_list COMA arg
;

arguments:
arg_list
| /*empty*/
;

arg: var_type WORD {
			 char * id = $<string_val>2;
			 local_vars_table[nlocals]=id;
			 local_vars_type[nlocals]=var_type;
			 nlocals++;
		 }
;

global_var: 
var_type global_var_list SEMICOLON;

global_var_list: WORD {
									 fprintf(fasm," # Make space for global vars\n");
									 fprintf(fasm,"\t.data\n");
									 fprintf(fasm, "\n.comm %s, 8\n", $<string_val>1);
									 fprintf(fasm,"\n");
									 global_vars_table[nglobals]=$<string_val>1;
									 global_vars_type[nglobals]=var_type;
									 nglobals++;
								 }
| global_var_list COMA WORD {
	fprintf(fasm, "\n.comm %s, 8\n", $<string_val>3);
	fprintf(fasm,"\n");
	global_vars_table[nglobals]=$<string_val>3;
	global_vars_type[nglobals]=var_type;
	nglobals++;
}
;

var_type: CHARSTAR {var_type = 0;} | CHARSTARSTAR {var_type=1;}| LONG {var_type = 1;}| LONGSTAR {var_type = 1;}| VOID {var_type = 1;};

assignment:
WORD EQUAL expression {
	char * id = $<string_val>1;
	int i;
	for (i=0; i<nlocals;i++) {
		if (!strcmp(local_vars_table[i], id)) {
			break;
		}
	}
	if (i==nlocals) {
		i = -1;
	}


	if (i>=0) {
		fprintf(fasm, "\tmovq %%%s, %d(%%rsp)\n", regStk[top-1], 8*(MAX_LOCALS-i) );
	}
	else {
		fprintf(fasm, "\tmovq %%%s, %s\n", regStk[top-1], id);
	}
	top--;
}
| WORD LBRACE expression RBRACE {
	char * id = $<string_val>1;
	int i;
	for (i=0; i<nlocals;i++) {
		if (!strcmp(local_vars_table[i], id)) {
			break;
		}
	}
	if (i==nlocals) {
		i = -1;
	}
	int type;

	if (i>=0) {
		type=		local_vars_type[i];
	} else{
	 int j;
	 for (j=0; j<nglobals;j++) {
		 if (!strcmp(global_vars_table[j], id)) {
			break;
		 }
	 }
	 if (j==nglobals) {
		j= -1;
	 }
	 type = global_vars_type[j];
	}



	if(type == 0)
	{
		fprintf(fasm, "\tmovq $1, %%rbp\n");
		fprintf(fasm, "\timulq %%rbp, %%%s\n", regStk[top-1]);
	}
	else 
	{
		fprintf(fasm, "\tshlq $3, %%%s\n", regStk[top-1]);
	}


	if (i>=0) {
		fprintf(fasm, "\tmovq %d(%%rsp), %%%s\n", 8*(MAX_LOCALS-i), regStk[top]);
		top++;
	}
	else {
		fprintf(fasm, "\tmovq %s, %%%s\n", id, regStk[top]);
		top++;
	}

	fprintf(fasm, "\taddq %%%s, %%%s\n", regStk[top-1], regStk[top-2]);
	top--;
}
EQUAL expression {
	fprintf(fasm, "\tmovq %%%s, (%%%s)\n", regStk[top-1], regStk[top-2]);
	top-=2;
}
;

call :
WORD LPARENT  call_arguments RPARENT {
	char * funcName = $<string_val>1;
	int nargs = $<nargs>3;
	int i;
	fprintf(fasm,"     # func=%s nargs=%d\n", funcName, nargs);
	fprintf(fasm,"     # Move values from reg stack to reg args\n");
	for (i=nargs-1; i>=0; i--) {
		top--;
		fprintf(fasm, "\tmovq %%%s, %%%s\n",
				regStk[top], regArgs[i]);
	}
	if (!strcmp(funcName, "printf")) {
		fprintf(fasm, "\tmovl    $0, %%eax\n");
	}
	fprintf(fasm, "\tcall %s\n", funcName);
	fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top]);
	top++;
}
;

call_arg_list:
expression {
	$<nargs>$=1;
}
| call_arg_list COMA expression {
	$<nargs>$++;
}

;

call_arguments:
call_arg_list { $<nargs>$=$<nargs>1; }
| /*empty*/ { $<nargs>$=0;}
;

expression :
logical_or_expr
;

logical_or_expr:
logical_and_expr
| logical_or_expr OROR logical_and_expr {
  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\torq %%%s,%%%s\n", regStk[top-1], regStk[top-2]);
  top--;
}
;

logical_and_expr:
equality_expr
| logical_and_expr ANDAND equality_expr {
  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\tandq %%%s,%%%s\n", regStk[top-1], regStk[top-2]);
  top--;
}
;

equality_expr:
relational_expr
| equality_expr EQUALEQUAL relational_expr {
  fprintf(fasm, "\tmovq  $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s, %%%s\n", regStk[top-1], regStk[top-2]);
  fprintf(fasm, "\tsete %%al\n");       
  fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top - 2]);
  top--;

}
| equality_expr NOTEQUAL relational_expr {
  fprintf(fasm, "\tmovq  $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s, %%%s\n", regStk[top-1], regStk[top-2]); 
  fprintf(fasm, "\tsetne %%al\n");        
  fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top - 2]);
  top--;
}
;

relational_expr:
additive_expr
| relational_expr LESS additive_expr {

  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s,%%%s\n", regStk[top-1], regStk[top-2]);
  fprintf(fasm, "\tsetl %%al\n");
  fprintf(fasm, "\tmovq %%rax,%%%s\n", regStk[top-2]);


  top--;

}
| relational_expr GREAT additive_expr {
  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s,%%%s\n", regStk[top-1], regStk[top-2]);
  fprintf(fasm, "\tsetg %%al\n");
  fprintf(fasm, "\tmovq %%rax,%%%s\n", regStk[top-2]);

  top--;

}
| relational_expr LESSEQUAL additive_expr {
  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s,%%%s\n", regStk[top-1], regStk[top-2]);
  fprintf(fasm, "\tsetle %%al\n");
  fprintf(fasm, "\tmovq %%rax,%%%s\n", regStk[top-2]);

  top--;

}
| relational_expr GREATEQUAL additive_expr {
  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s,%%%s\n", regStk[top-1], regStk[top-2]);
  fprintf(fasm, "\tsetge %%al\n");
  fprintf(fasm, "\tmovq %%rax,%%%s\n", regStk[top-2]);

  top--;

}
;

additive_expr:
multiplicative_expr
| additive_expr PLUS multiplicative_expr {
  if (top<nregStk) {
    fprintf(fasm, "\taddq %%%s,%%%s\n",
        regStk[top-1], regStk[top-2]);
    top--;
  }
}
| additive_expr MINUS multiplicative_expr {
  if  (top <nregStk) {
    fprintf(fasm, "subq %%%s,%%%s\n", regStk[top-1], regStk[top-2]);
    top--;
  }
}
;

multiplicative_expr:
primary_expr
| multiplicative_expr TIMES primary_expr {
  if (top<nregStk) {
    fprintf(fasm, "\timulq %%%s,%%%s\n",
        regStk[top-1], regStk[top-2]);
    top--;
  }
}
| multiplicative_expr DIVIDE primary_expr {
  if (top<nregStk) {
    fprintf(fasm, "movq %%%s,%%rax\n", regStk[top-2]);
    fprintf(fasm, "\tcqo\n");
    fprintf(fasm, "idivq %%%s\n", regStk[top-1]);
    fprintf(fasm, "movq %%rax,%%%s\n", regStk[top-2]);

    top--;
  }
}
| multiplicative_expr PERCENT primary_expr {
  if (top<nregStk) {
    fprintf(fasm, "movq %%%s,%%rax\n", regStk[top-2]);
    fprintf(fasm, "\tcqo\n");
    fprintf(fasm, "idivq %%%s\n", regStk[top-1]);
    fprintf(fasm, "movq %%rdx,%%%s\n", regStk[top-2]);

    top--;
  }
}

;

primary_expr:
STRING_CONST {
	string_table[nstrings]=$<string_val>1;
	if (top<nregStk) {
		fprintf(fasm, "\tmovq $string%d, %%%s\n", 
				nstrings, regStk[top]);
		top++;
	}
	nstrings++;
}
| call
| WORD {
	char * id = $<string_val>1;

	int i;
	for (i=0; i<nlocals;i++) {
		if (!strcmp(local_vars_table[i], id)) {
			break;
		}
	}
	if (i==nlocals) {
		i = -1;
	}
	if (i>=0) {
		fprintf(fasm, "\tmovq %d(%%rsp), %%%s\n", 8*(MAX_LOCALS-i), 
				regStk[top]);
		top++;
	}
	else {
		fprintf(fasm, "\tmovq %s, %%%s\n", id, regStk[top]);
		top++;
	}
}
| WORD LBRACE expression RBRACE {

	char * id = $<string_val>1;

	int i;
	for (i=0; i<nlocals;i++) {
		if (!strcmp(local_vars_table[i], id)) {
			break;
		}
	}
	if (i==nlocals) {
		i = -1;
	}
	int type;

	if (i>=0) {
		type=		local_vars_type[i];
	} else{
	 int j;
	 for (j=0; j<nglobals;j++) {
		 if (!strcmp(global_vars_table[j], id)) {
			break;
		 }
	 }
	 if (j==nglobals) {
		j= -1;
	 }
	 type = global_vars_type[j];
	}


	
	if(type == 0)
	{
		fprintf(fasm, "\tmovq $1, %%rbp\n");

		fprintf(fasm, "\timulq %%rbp, %%%s\n", regStk[top-1]);
	}
	else 
	{
		fprintf(fasm, "\tshlq $3, %%%s\n", regStk[top-1]);
	}


	if (i>=0) {
		fprintf(fasm, "\tmovq %d(%%rsp), %%%s\n", 8*(MAX_LOCALS-i), regStk[top]);
		top++;
	}
	else {
		fprintf(fasm, "\tmovq %s, %%%s\n", id, regStk[top]);
		top++;
	}

	fprintf(fasm, "\taddq %%%s, %%%s\n", regStk[top-1], regStk[top-2]);
	top--;

	fprintf(fasm, "\tmovq (%%%s), %%%s\n", regStk[top-1], regStk[top-1]);

	if(type == 0)
	{
		fprintf(fasm, "\tmovb %%%s, %%bpl\n", byteRegisters[top-1]);
		fprintf(fasm, "\txor %%%s, %%%s\n", regStk[top-1], regStk[top-1]);
		fprintf(fasm, "\tmovb %%bpl, %%%s\n", byteRegisters[top-1]);
	}



}
| AMPERSAND WORD {
	
	char * id = $<string_val>2;

	int i;
	for (i=0; i<nlocals;i++) {
		if (!strcmp(local_vars_table[i], id)) {
			break;
		}
	}
	if (i==nlocals) {
		i = -1;
	}

	if (i>=0) {
		fprintf(fasm, "\tleaq %d(%%rsp), %%%s\n", 8*(MAX_LOCALS-i), regStk[top]);
		top++;
	}
	else {
		fprintf(fasm, "\tleaq %s, %%%s\n", id, regStk[top]);
		top++;
	}

}
| INTEGER_CONST {
	if (top<nregStk) {
		fprintf(fasm, "\tmovq $%s,%%%s\n", 
				$<string_val>1, regStk[top]);
		top++;
	}
}
| LPARENT expression RPARENT
;

compound_statement:
LCURLY statement_list RCURLY
;

statement_list:
statement_list statement
| /*empty*/
;

local_var:
var_type local_var_list SEMICOLON;

local_var_list: WORD {

									local_vars_table[nlocals]=$<string_val>1;
									local_vars_type[nlocals]=var_type;
									nlocals++;
								}
| local_var_list COMA WORD {
	local_vars_table[nlocals]=$<string_val>3;
	local_vars_type[nlocals]=var_type;
	nlocals++;
}
;

statement:
assignment SEMICOLON
| call SEMICOLON {
	top = 0;
}
| local_var
| compound_statement
| IF LPARENT expression RPARENT {
  if_label++;
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
  fprintf(fasm, "\tje tempEnd_%d\n", if_label);
  top--;
}
statement {
  fprintf(fasm, "\tjmp the_actual_end_%d\n", if_label);
  fprintf(fasm, "\ttempEnd_%d:\n", if_label);

}  else_optional {
  fprintf(fasm, "\tthe_actual_end_%d:\n", if_label);
}
| WHILE LPARENT {
  $<my_nlabel>1=nlabel;
  nlabel++;
  fprintf(fasm, "begin_loop_%d:\n", $<my_nlabel>1);
  fprintf(fasm, "keep_going_%d:\n", $<my_nlabel>1);

}
expression RPARENT {
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
  fprintf(fasm, "\tje loop_end_%d\n", $<my_nlabel>1);
  top--;
}
statement {
  fprintf(fasm, "\tjmp begin_loop_%d\n", $<my_nlabel>1);
  fprintf(fasm, "loop_end_%d:\n", $<my_nlabel>1);
}
| DO {
  $<my_nlabel>1 = nlabel;
  nlabel++;
  fprintf(fasm, "begin_loop_%d:\n", $<my_nlabel>1);
  fprintf(fasm, "keep_going_%d:\n", $<my_nlabel>1);

} statement WHILE LPARENT expression {
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
  fprintf(fasm, "\tjne begin_loop_%d\n", $<my_nlabel>1);
  top--;
}
RPARENT SEMICOLON {
  fprintf(fasm, "loop_end_%d:\n", $<my_nlabel>1);
}
| FOR LPARENT assignment SEMICOLON {
  $<my_nlabel>1 = nlabel;
  nlabel++;
  fprintf(fasm, "begin_loop_%d:\n", $<my_nlabel>1);
	
}
expression {
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
  fprintf(fasm, "\tje loop_end_%d\n", $<my_nlabel>1);
  fprintf(fasm, "\tjne body_of_loop_%d\n", $<my_nlabel>1);
  top--;
}
SEMICOLON {
  fprintf(fasm, "keep_going_%d:\n", $<my_nlabel>1);
}
assignment {
  fprintf(fasm, "\tjmp begin_loop_%d\n", $<my_nlabel>1);
}
RPARENT {
  fprintf(fasm, "\tbody_of_loop_%d:\n", $<my_nlabel>1);
}
statement {
  fprintf(fasm, "\tjmp keep_going_%d\n", $<my_nlabel>1);
  fprintf(fasm, "loop_end_%d:\n", $<my_nlabel>1);

}
| jump_statement
;

else_optional:
ELSE  statement
| /* empty */
;

jump_statement:
CONTINUE SEMICOLON {
  $<my_nlabel>1 = nlabel;

  fprintf(fasm, "\tjmp keep_going_%d\n", $<my_nlabel>1 - 1 );
}
| BREAK SEMICOLON {
  $<my_nlabel>1 = nlabel;

  fprintf(fasm, "\tjmp  loop_end_%d\n", $<my_nlabel>1 - 1 );
}
| RETURN expression SEMICOLON {
  fprintf(fasm, "\tmovq %%rbx, %%rax\n");
  top = 0;
	 fprintf(fasm, "\taddq $%d,%%rsp\n", 8*MAX_LOCALS);
		 fprintf(fasm, "\tpopq %%r15\n");
		 fprintf(fasm, "\tpopq %%r14\n");
		 fprintf(fasm, "\tpopq %%r13\n");
		 fprintf(fasm, "\tpopq %%r10\n");
		 fprintf(fasm, "\tpopq %%rbx\n");
		 fprintf(fasm, "\tret\n");
}
;


%%

void yyset_in (FILE *  in_str );

	int
yyerror(const char * s)
{
	fprintf(stderr,"%s:%d: %s\n", input_file, line_number, s);
}


	int
main(int argc, char **argv)
{
	printf("-------------WARNING: You need to implement global and local vars ------\n");
	printf("------------- or you may get problems with top------\n");

	// Make sure there are enough arguments
	if (argc <2) {
		fprintf(stderr, "Usage: simple file\n");
		exit(1);
	}

	// Get file name
	input_file = strdup(argv[1]);

	int len = strlen(input_file);
	if (len < 2 || input_file[len-2]!='.' || input_file[len-1]!='c') {
		fprintf(stderr, "Error: file extension is not .c\n");
		exit(1);
	}

	// Get assembly file name
	asm_file = strdup(input_file);
	asm_file[len-1]='s';

	// Open file to compile
	FILE * f = fopen(input_file, "r");
	if (f==NULL) {
		fprintf(stderr, "Cannot open file %s\n", input_file);
		perror("fopen");
		exit(1);
	}

	// Create assembly file
	fasm = fopen(asm_file, "w");
	if (fasm==NULL) {
		fprintf(stderr, "Cannot open file %s\n", asm_file);
		perror("fopen");
		exit(1);
	}

	// Uncomment for debugging
	//fasm = stderr;

	// Create compilation file
	// 
	yyset_in(f);
	yyparse();

	// Generate string table
	int i;
	for (i = 0; i<nstrings; i++) {
		fprintf(fasm, "string%d:\n", i);
		fprintf(fasm, "\t.string %s\n\n", string_table[i]);
	}

	fclose(f);
	fclose(fasm);

	return 0;
}



