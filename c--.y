%{
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include "symbolTable.h"
#include "y.tab.h"

// line number in input file
extern int yylineno;


// pointer to hash table
struct Symbol * symbolTable = NULL;
struct Symbol * symbolTable2 = NULL;

// identify the current scope of parsing
int scopeLevel;

// current available register to use in generate_code()
// its the resposnibility of the user to increment or decrement
// the value of the available register
int reg = 0;

// given a node, generate the code according to the parse tree
// -n tree head
void generate_code(struct Node * n);

// makes a variable node in the parse tree, use it in grammer rules
// when the rule refers to a variable. The node created will especify
// how the asembly code will be generated according to the usage of the
// variable
//
// -name: name of the varialbe to be stored in the node
// -used: 1 if the variable is read, 0 if its assigned
//
// returns: node pointer to a variable node
struct Node * make_identifier(char name[], char used);

// makes a const value node in the parse tree, use it in grammer rules
// when the rule refers to a variable. The node created will especify
// how the asembly code will be generated according to the type of const
//
// -value: actual value of variable
// -type: type of variable
//
// returns: node pointer to a const node
struct Node * make_constant(YYSTYPE value, VariableType type);

// makes an operation node in the parse tree, use in grammer rules
// when the rule refers to an operation. Also you can make special
// operations for statement_lists to treat them differently. The
// node created will especify how the asembly code will be generated
// according to the type of operation.
//
// -operation: operation number, use operation ASCII or Enums from lexxer
// -nOfOperands: number of operands to specify the size of variable argument list
// -argument list: arguments of the operations, must be same number of nOfOperands
//
// returns: node pointer to an operation
struct Node * make_operation(int operation, int nOfOperands, ... );

// free the tree of nodes
//
// -n: tree root
void free_node(struct Node * n);

// creates or checks the existance of variables in symbol table.
// this function will raise yyerrors in case of variable error.
// variable could be new one to be added, const variable used,
// undeclared variable, or reference to a global variable (see issue#13)
//
// -yytext: variable name, call scope_handler(yytext) first to resolve variable scope
// -isConst: 1 if variable is const
// - def: 0 if variable is assigned, 1 if its decleration of variable or
//      2 if variable is read
//
// notes: see issue#13
void variableHandler(char yytext[], char isConst, char def);

// read char data from a string
// eg: "'4'" = '4'
char validate_char(char * yytext);

// print the variables in symbol table to the output stream
void make_dataSegment();

// missing documentation!
void print_hashTable();

// print the equivalent assembly code of a given parse tree
//
// -tree: parse tree root
void make_codeSegment(struct Node * tree);

// missing documentation!
void printTree(struct Node * n,int lvl,int from,int to,int num);

// safe way to assign a char sequence another to the value of other one
//
// -txt: char sequence to be copied
//
// returns: char sequence with same value as txt
char * newstr(char * txt);

// resolve the scope of a give  by prefixing its name with its scope
// information
//
// -txt: variable name
//
// returns: new variable name that specifies its scope information
char * scope_resolution(char *txt);

// const value holder
YYSTYPE Const;


int sfrom=0,sto=1;
int scopes[110][110];
int ** scope_ptr;

int labl=0, labll=0;
int llbl,loop_lbl=0;
int brn_lbl=0;
// make sure only 1 default at maximum appears in switch body
int default_walker=-1, number_default[] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

typedef enum {EQ, BQ, LQ, NQ} logicalOp;
#define IF_ELSE 213123
/////////////////////////////////////////////////////////////////////////////
%}

%union {
    int ival;
    char cval;
    double dval;
    struct Node * node_ptr;
    char * iname;
    char * sval;
};

%start list

%token <ival> INT
%token <dval> DOUBLE
%token <cval> CHAR
%token <sval> STRING
%token <iname> VARIABLE

%token AOP LOP HAN3RF
%token IF SWITCH ELSE ELSIF CASE DEFAULT TRUE FALSE CONST
%token DO WHILE FOR AND OR NOT BREAK CONTINUE
%token LQ_T BQ_T EQ_T NQ_T

%type <node_ptr> list statement switch_body_statement case_list_statement case_statement statement_list parantasis_statement assignment_statement expr assignment_expr
%type <node_ptr> string_expr declartion_statement control_statement jump_statement const_value
%type <node_ptr> loop_statement for_statement while_statement do_statement opexpr assignment_statement2 if_statement

%left "==" '>' '<' "!=" ">=" "<="
%left '-' '+'
%left '*' '/'
%left '|' '&'  '~'
%right '^'
%left UMINUS

%%
    list
        : list statement {	 make_codeSegment($2);}
        | {$$=NULL;}
        ;

    statement
		: assignment_statement        {$$=$1;}
		| declartion_statement        {$$=$1;}
        | control_statement           {$$=$1;}
        | parantasis_statement        {$$=$1;}
		| expr ';'                    {$$=$1;}
		| loop_statement			  {$$=$1;}
		| if_statement				  {$$=$1;}
	    ;

	loop_statement
		:for_statement 				  {$$=$1;}
		|while_statement 			  {$$=$1;}
		|do_statement 				  {$$=$1;}
		;
	for_statement
		:FOR '(' opexpr ';' opexpr ';' opexpr ')' statement {  $$ = make_operation(FOR, 4, $3, $5,$7,$9 );}
		;
	while_statement
		:WHILE '(' opexpr ')' statement {$$ = make_operation(WHILE, 2, $3, $5 );}
		;
	do_statement
		:DO statement WHILE '('opexpr ')' {$$=make_operation(DO, 2, $2, $5 );}
		;
    opexpr
    	: assignment_statement2{$$=$1;}
		| expr {$$=$1;}
		| {$$=NULL;}
		;
    
	assignment_statement2
        : VARIABLE '=' assignment_expr
        	{variableHandler(scope_resolution($1), 0, 0); $$=make_operation( '=', 2, make_identifier($1, 0), $3 );}
        | CONST VARIABLE '=' assignment_expr     {variableHandler(scope_resolution($2), 1, 1); $$=make_operation( '=', 2, make_identifier($2, 0), $4 );}
        | HAN3RF VARIABLE '=' assignment_expr  {variableHandler(scope_resolution($2), 0, 1); $$=make_operation( '=', 2, make_identifier($2, 0), $4 );}
        ;


	if_statement
		:IF '(' opexpr ')' statement 				{$$=make_operation(IF, 2, $3, $5 );}
		|IF '(' opexpr ')' statement ELSE statement {$$=make_operation(IF_ELSE, 3, $3, $5,$7 );}
		;




    switch_body_statement
        :   case_statement             {$$=$1;}
        | '{' case_list_statement '}'  {$$=$2;}
        ;

    case_list_statement
        : case_statement                        {$$ = $1;}
        | case_list_statement case_statement    {$$ = make_operation('c', 2, $1, $2);}
        ;

    case_statement
        : CASE const_value ':' statement  jump_statement ';'  {   $$ = make_operation(CASE, 3, $2, $4, $5);  }
        | DEFAULT ':' statement jump_statement ';'               {   $$ = make_operation(DEFAULT, 2, $3, $4);  }
        ;

    parantasis_statement
        : '{' statement_list '}'   {$$=$2;}
        ;

    statement_list
        : statement {$$=$1;}
        | statement_list statement  {$$=make_operation('s', 2, $1, $2);}
        ;

    control_statement
        : SWITCH '(' VARIABLE ')' switch_body_statement { variableHandler(scope_resolution($3), 0, 2);  $$ = make_operation(SWITCH, 2, make_identifier($3, 1), $5 );   }
        ;

    jump_statement
        : BREAK   {   $$ = make_operation(BREAK, 0);  }
        | {$$=NULL;}
        ;

	assignment_statement
        : VARIABLE '=' assignment_expr ';'
        	{variableHandler(scope_resolution($1), 0, 0); $$=make_operation( '=', 2, make_identifier($1, 0), $3 );}
        | CONST VARIABLE '=' assignment_expr ';'    {variableHandler(scope_resolution($2), 1, 1); $$=make_operation( '=', 2, make_identifier($2, 0), $4 );}
        | HAN3RF VARIABLE '=' assignment_expr ';' {variableHandler(scope_resolution($2), 0, 1); $$=make_operation( '=', 2, make_identifier($2, 0), $4 );}
		;
	
		;
	assignment_expr
		: expr        {$$=$1;}
		| string_expr {$$=$1;}
		;

    const_value
        : '(' const_value ')'   { $$ = $2;}
        | INT                   { (Const.ival=$1); $$=make_constant(Const,tINT);}
        | STRING                { (Const.sval=newstr($1)); $$=make_constant(Const,tSTRING);}
        | CHAR                  { (Const.cval=$1); $$=make_constant(Const,tCHAR);}
        | DOUBLE                { (Const.dval=$1); $$= make_constant(Const,tDOUBLE);}
        ;

	string_expr
		: STRING                { (Const.sval=newstr($1)); $$=make_constant(Const,tSTRING);}
		;

	declartion_statement
		: HAN3RF VARIABLE ';' {variableHandler(scope_resolution($2), 0, 1);$$=NULL;}
		;

	expr
		:
		VARIABLE {variableHandler(scope_resolution($1), 0, 2); $$=make_identifier($1, 1);}
		|
		INT
		    { (Const.ival=$1); $$=make_constant(Const,tINT);
		    }
		|
		DOUBLE
		    { (Const.dval=$1); $$= make_constant(Const,tDOUBLE);
		    }
		|
		CHAR
		{
		    { (Const.cval=$1); $$=make_constant(Const,tCHAR);}
		}
		|
		expr EQ_T expr
		    {
				$$ = make_operation( EQ, 2, $1, $3 );
		    }
		|
		expr NQ_T expr
		    {
				$$ = make_operation( NQ, 2, $1, $3 );
		    }
		|
		expr LQ_T expr
		    {
				$$ = make_operation( LQ, 2, $1, $3 );
		    }
		|
		expr BQ_T expr
		    {
				$$ = make_operation( BQ, 2, $1, $3 );
		    }
		|
		expr '<' expr
		    {
				$$ = make_operation( '<', 2, $1, $3 );
		    }
		|
		expr '>' expr
		    {
				$$ = make_operation( '>', 2, $1, $3 );
		    }
		|
		expr '*' expr
		    {
			    $$ = make_operation( '*', 2, $1, $3 );
		    }
		|
		expr '/' expr
		    {
			    $$ = make_operation( '/', 2, $1, $3 );
		    }
		|
		expr '+' expr
		    {
			    $$ = make_operation( '+', 2, $1, $3 );
		    }
		|
		expr '-' expr
		    {
				$$ = make_operation( '-',2, $1, $3 );
		    }
		|
		expr '|' expr
		    {
				$$ = make_operation( '|', 2, $1, $3 );
		    }
		|
		expr '&' expr
		    {
				$$ = make_operation( '&', 2, $1, $3 );
		    }
		|
		expr '^' expr
		    {
				$$ = make_operation( '^', 2, $1, $3 );
		    }
		|
		'~' expr
		    {
				$$ = make_operation( '~', 1, $2 );
		    }
		|
		'-' expr %prec  UMINUS
		    {
				$$ = make_operation( '-', 1, $2 );
		    }
		|
		'(' expr ')'
         {
           $$ = $2;
         }
		;

%%


// allocate new string
char * newstr(char * txt)
{
	char *ret;
	if((ret=malloc(strlen(txt)) )== NULL)
        yyerror("out of memory");

	strcpy(ret,txt);
	return ret;
}


char * scope_resolution(char *txt)
{
	char tmp[50];
	sprintf(tmp,"_%d%d%d",sfrom,sto,scopes[sfrom][sto]);
	strcat(txt,tmp);
	return txt;
}
void printTree(struct Node * n,int lvl,int from,int to,int num)
{
	if(n==NULL)return;
	int i;

	for(i=0;i<lvl;i++)
	{
		printf("%3c",' ');
	}
	if(n->type==OPERATION)
	{
		if(n->opr.operation=='s')
		{
			printf("OP -> %c (%d,%d,%d)\n",n->opr.operation,from,to,scopes[from][to]);
			printTree(n->opr.op[0],lvl+1,from+1,to+1,num);
			printTree(n->opr.op[1],lvl+1,from+1,to+1,num);

		}
		else
		{
			printf("OP -> %c\n",n->opr.operation);
			printTree(n->opr.op[0],lvl+1,from,to,num);
			printTree(n->opr.op[1],lvl+1,from,to,num);
		}
	}
	else if(n->type==CONSTANT)
	{
		printf("const -> %d\n",n->con.ival);
	}
	else if(n->type==IDENTIFIER)
	{
		printf("identifier -> %s\n",n->id.name);
	}
}
void generate_code(struct Node * n)
{
    if (n == NULL) return;  // in case there is no tree

    int ca, labl2;
    int clbl;
    // check the type of the node
    switch(n->type)
    {

        // check the type of the operation
        case OPERATION:
            switch(n->opr.operation)
            {
                    case FOR:
                    	//sfrom++;sto++;++scopes[sfrom][sto];
                    	llbl=++loop_lbl;
                    	clbl=llbl;
                    	printf("#=====init=======\n");
                    	generate_code(n->opr.op[0]);
                    	printf("looplable_%d:\n",clbl);
                    	printf("#-----cond-----\n");
                    	generate_code(n->opr.op[1]);
                    	if(n->opr.op[1]!=NULL)// da law fe condition 
                    	{
                    		char cond[4];
                    		if(n->opr.op[1]->opr.operation=='<')
                    		printf("JBQ Endloop_lable_%d\n",clbl);
                    		if(n->opr.op[1]->opr.operation=='>')
                    		printf("JLQ Endloop_lable_%d\n",clbl);
                    		if(n->opr.op[1]->opr.operation==BQ)
                    		printf("JL Endloop_lable_%d\n",clbl);
                    		if(n->opr.op[1]->opr.operation==LQ)
                    		printf("JB Endloop_lable_%d\n",clbl);
                    		if(n->opr.op[1]->opr.operation==EQ)
                    		printf("JNQ Endloop_lable_%d\n",clbl);
                    		if(n->opr.op[1]->opr.operation==NQ)
                    		printf("JEQ Endloop_lable_%d\n",clbl);
                    		//printf("%s Endloop_lable_%d\n",cond,llbl);
                    	}
                    	
                    	printf("#-----statement-----\n");
                    	generate_code(n->opr.op[3]);
                    	printf("#-----step-----\n");
                    	generate_code(n->opr.op[2]);
                    	printf("JMP looplable_%d\n",clbl);
                    	printf("#=====end=======\n");
                    	printf("Endloop_lable_%d:\n",clbl);
                    	//sfrom--;sto--;
                    	break;
                    case WHILE:
                    	//sfrom++;sto++;++scopes[sfrom][sto];
                    	llbl=++loop_lbl;
                    	clbl=llbl;
                    	printf("#=====cond=======\n");
                    	
                    	printf("looplable_%d:\n",clbl);
                    	
                    	generate_code(n->opr.op[0]);
                    	if(n->opr.op[0]!=NULL)// da law fe condition 
                    	{
                    		char cond[4];
                    		if(n->opr.op[0]->opr.operation=='>')
                    		printf("JLQ Endloop_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation=='<')
                    		printf("JBQ Endloop_lable_%d\n",clbl);
                    		
                    		if(n->opr.op[0]->opr.operation==BQ)
                    		printf("JL Endloop_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation==LQ)
                    		printf("JB Endloop_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation==EQ)
                    		printf("JNQ Endloop_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation==NQ)
                    		printf("JEQ Endloop_lable_%d\n",clbl);
                    		//printf("%s Endloop_lable_%d\n",cond,llbl);
                    	}
                    	
                    	printf("#-----statement-----\n");
                    	generate_code(n->opr.op[1]);
                    	printf("JMP looplable_%d\n",clbl);
                    	printf("#=====end=======\n");
                    	printf("Endloop_lable_%d:\n",clbl);
                    	//sfrom--;sto--;
                    	break;
                    
                    case DO:
                    	//sfrom++;sto++;++scopes[sfrom][sto];
                    	llbl=++loop_lbl;
                    	clbl=llbl;
                    	printf("#===============\n");
                    	
                    	printf("looplable_%d:\n",clbl);
                    	printf("#-----statement-----\n");
                    	generate_code(n->opr.op[0]);
                    	printf("#-----cond-----\n");
                    	generate_code(n->opr.op[1]);
                    	if(n->opr.op[1]!=NULL)// da law fe condition 
                    	{
                    		char cond[4];
                    		if(n->opr.op[1]->opr.operation=='>')
                    		printf("JB loop_lable_%d\n",clbl);
                    		if(n->opr.op[1]->opr.operation=='<')
                    		printf("JL loop_lable_%d\n",clbl);
                    		
                    		if(n->opr.op[1]->opr.operation==BQ)
                    		printf("JBQ loop_lable_%d\n",clbl);
                    		if(n->opr.op[1]->opr.operation==LQ)
                    		printf("JLQ loop_lable_%d\n",clbl);
                    		if(n->opr.op[1]->opr.operation==EQ)
                    		printf("JEQ loop_lable_%d\n",clbl);
                    		if(n->opr.op[1]->opr.operation==NQ)
                    		printf("JNQ loop_lable_%d\n",clbl);
                    		//printf("%s Endloop_lable_%d\n",cond,llbl);
                    	}
                    	
                    	
                    	//printf("JMP looplable_%d\n",clbl);
                    	printf("#=====end=======\n");
                    	printf("Endloop_lable_%d:\n",clbl);
                    	//sfrom--;sto--;
                    	break;
                    
                    case IF_ELSE:
                    	clbl=++brn_lbl;
                    	printf("#-----cond-----\n");
                    	generate_code(n->opr.op[0]);
                    	if(n->opr.op[0]!=NULL)// da law fe condition 
                    	{
                    		char cond[4];
                    		if(n->opr.op[0]->opr.operation=='>')
                    		printf("JLQ branch_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation=='<')
                    		printf("JBQ branch_lable_%d\n",clbl);
                    		
                    		if(n->opr.op[0]->opr.operation==BQ)
                    		printf("JL branch_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation==LQ)
                    		printf("JB branch_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation==EQ)
                    		printf("JNQ branch_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation==NQ)
                    		printf("JEQ branch_lable_%d\n",clbl);
                    		//printf("%s Endloop_lable_%d\n",cond,llbl);
                    	}
                    	printf("#-----statement----\n");
                    	generate_code(n->opr.op[1]);
                    	printf("JMP End_branch_lable_%d:\n",clbl);
                    	printf("branch_lable_%d:\n",clbl);
                    	printf("#-----else statement----\n");
                    	generate_code(n->opr.op[2]);
                    	printf("End_branch_lable_%d:\n",clbl);
                    	
                    	break;
                    case IF:
                    	clbl=++brn_lbl;
                    	printf("#-----cond-----\n");
                    	generate_code(n->opr.op[0]);
                    	if(n->opr.op[0]!=NULL)// da law fe condition 
                    	{
                    		char cond[4];
                    		if(n->opr.op[0]->opr.operation=='>')
                    		printf("JLQ branch_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation=='<')
                    		printf("JBQ branch_lable_%d\n",clbl);
                    		
                    		if(n->opr.op[0]->opr.operation==BQ)
                    		printf("JL branch_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation==LQ)
                    		printf("JB branch_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation==EQ)
                    		printf("JNQ branch_lable_%d\n",clbl);
                    		if(n->opr.op[0]->opr.operation==NQ)
                    		printf("JEQ branch_lable_%d\n",clbl);
                    		//printf("%s Endloop_lable_%d\n",cond,llbl);
                    	}
                    	printf("#-----statement----\n");
                    	generate_code(n->opr.op[1]);
                    	printf("branch_lable_%d:\n",clbl);
                    	
                    	break;
                    	
                    
                    case '<'://logical operation assum CMP saving in register FLAGS E,G,L,GE,LE => "==",">","<", ..
                    	generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("CMP R%d, R%d\n", reg, reg-1);
        				reg -= 2;
                    	break;
                    case '>'://logical operation assum CMP saving in register FLAGS E,G,L,GE,LE => "==",">","<", ..
                    	generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("CMP R%d, R%d\n", reg, reg-1);
        				reg -= 2;
                    	break;
                   	case EQ://logical operation assum CMP saving in register FLAGS E,G,L,GE,LE => "==",">","<", ..
                    	generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("CMP R%d, R%d\n", reg, reg-1);
        				reg -= 2;
                    	break;
                    case BQ://logical operation assum CMP saving in register FLAGS E,G,L,GE,LE => "==",">","<", ..
                    	generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("CMP R%d, R%d\n", reg-1, reg);
        				reg -= 2;
                    	break;
                    case LQ://logical operation assum CMP saving in register FLAGS E,G,L,GE,LE => "==",">","<", ..
                    	generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("CMP R%d, R%d\n", reg, reg-1);
        				reg -= 2;
                    	break;
                    case NQ://logical operation assum CMP saving in register FLAGS E,G,L,GE,LE => "==",">","<", ..
                    	generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("CMP R%d, R%d\n", reg, reg-1);
        				reg -= 2;
                    	break;
                    	
                    	
                    case SWITCH:
                        default_walker++;
                        // move the switch variable to a register
                        generate_code(n->opr.op[0]);
                        labll++;

                        // generate the switch body
                        generate_code(n->opr.op[1]);

                        // label the end of the switch statement
                        printf("switch_labl%d:\n", labll--);

                        // check the number of defualt statements that appeared
                        // in the switch body
                        if (number_default[default_walker] > 1)
                        {
                            yyerror("multiple default labels in one switch");
                        }

                        default_walker--;

                        reg -= 1;
                        break;
                    case CASE:
                        generate_code(n->opr.op[1]);
                        if (n->opr.op[2] != NULL)
                            generate_code(n->opr.op[2]);
                        break;

                    case DEFAULT:
                        number_default[default_walker] += 1;

                        generate_code(n->opr.op[0]);
                        if (n->opr.op[1] != NULL)
                            generate_code(n->opr.op[1]);
                        break;
                    case BREAK:
                        printf("JMP switch_labl%d\n", labll);
                        break;

                    case 'c':
                        // case statement special operations
                        // that connect list of case statements that follows
                        // each other. Goal here is to make all conditions first
                        // then followed by the body of the case statements

                        // generate the code of case statements conditions first
                        for (ca = 0; ca <2; ca++)
                            if (n->opr.op[ca]->opr.op[0] != NULL && n->opr.op[ca]->type == OPERATION && n->opr.op[ca]->opr.operation == CASE)
                            {
                                
                                generate_code(n->opr.op[ca]->opr.op[0]);
                                // compare it
                                printf("CMP R%d, R%d\n", reg-1, reg);
                                printf("JE case_labl%d\n", labl2 = labl++);
                                reg -= 1;
                            }
                            else if (n->opr.op[ca]->opr.op[0] != NULL && n->opr.op[ca]->type == OPERATION && n->opr.op[ca]->opr.operation == DEFAULT)
                            {
                                printf("JMP case_labl%d\n", labl2 = labl++);
                                labl++;
                            }

                        // generate the code of case statements body
                        for (ca = 1; ca >=0; ca--)
                            if (n->opr.op[ca] != NULL )
                            {
                                printf("case_labl%d:\n", labl2--);
                                generate_code(n->opr.op[ca]);
                            }


                        break;
                    // dummy operation for joining to statements together
                    // see statement_list grammer
        			case 's':
            			if(n->opr.op[0]!=NULL)
            			generate_code(n->opr.op[0]);
            			if(n->opr.op[1]!=NULL)
        				generate_code(n->opr.op[1]);
        				break;
        			case '=':
        			    generate_code(n->opr.op[1]);
        			    printf("MOV %s, R%d\n", n->opr.op[0]->id.name, reg);
        				break;
        			case '*':
        				generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("MUL R%d, R%d, R%d\n", reg-1, reg, reg-1);
        				reg -= 1;
        				break;
            		case '+':
        				generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("ADD R%d, R%d, R%d\n", reg-1, reg, reg-1);
        				reg -= 1;
        				break;
        			case '-':
        				generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("SUB R%d, R%d, R%d\n", reg-1, reg, reg-1);
        				reg -= 1;
        				break;
        			case '/':
        				generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("DIV R%d, R%d, R%d\n", reg-1, reg, reg-1);
        				reg -= 1;
        				break;
        		    case '|':
        		        generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("OR R%d, R%d, R%d\n", reg-1, reg, reg-1);
        				reg -= 1;
        		        break;
        		    case '&':
        		        generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("AND R%d, R%d, R%d\n", reg-1, reg, reg-1);
        				reg -= 1;
        		        break;
        		    case '~':
        				generate_code(n->opr.op[0]);
        				printf("NEG R%d, R%d\n", reg-1, reg);
        				reg -= 1;
        		        break;
        		    case '^':
        		        generate_code(n->opr.op[1]);
        				generate_code(n->opr.op[0]);
        				printf("XOR R%d, R%d, R%d\n", reg-1, reg, reg-1);
        				reg -= 1;
        				break;
        		    case UMINUS:
        		        generate_code(n->opr.op[0]);
        				printf("NEG R%d, R%d\n", reg-1, reg);
        				reg -= 1;
        		        break;

            }
            break;

        case IDENTIFIER:
            if (n->id.usage == 1)
            {   reg+=1; printf("MOV R%d, %s\n", reg, n->id.name);   }
            else
            printf("MOV %s, R%d\n", n->id.name, reg);
        break;

        case CONSTANT:
        	switch(n->con.type)
        	{
        		case tINT:
        			reg += 1; printf("MOV R%d, %d\n",reg, n->con.ival);
        			break;
        		case tDOUBLE:
        			reg += 1; printf("MOV R%d, %f\n",reg, n->con.dval);
        			break;
        		case tCHAR:
        			reg += 1; printf("MOV R%d, '%c'\n",reg, n->con.cval);
        			break;
        	}
        break;

        default:
            // no node should be typless
            return;
    }
}

// handle a varialbe usage
// @param used either 1 or 0, 1 if the variable is read, 0 if its assigned
struct Node * make_identifier(char name[], char used)
{
    struct Node *n;
    size_t nodeSize;

    /* allocate node */
    nodeSize = SIZEOF_NODETYPE + sizeof(IdentifierNodeType);

    if ((n = (struct Node * )malloc(nodeSize)) == NULL)
        yyerror("out of memory");

    /* copy information */
    n->type = IDENTIFIER;

    if (used == 1)   n->id.usage = 1;
    else n->id.usage = 0;

    n->id.name=newstr(name);
    //strcpy(n->id.name, name);
    return n;
}

// handle a const usage
// @param value actual value of the const, use the 'Const' varialbe to allocate it
// @param type of the variable
struct Node * make_constant(YYSTYPE value, VariableType type)
{
    struct Node * n;
    size_t nodeSize;

    /* allocate node */
    nodeSize = SIZEOF_NODETYPE + sizeof(ConstantNodeType);


    if ((n = (struct Node *)malloc(nodeSize)) == NULL)
        return NULL;

    /* copy information */
    n->type = CONSTANT;
    n->con.type=type;// to indicate the type of the constant

    switch (type)
    {
        case tINT:
            n->con.ival = value.ival;
            break;

        case tDOUBLE:
            n->con.dval = value.dval;
            break;

        case tSTRING:
            strcpy(n->con.sval, value.sval);
            break;

        case tCHAR:
            n->con.cval = value.cval;
            break;

        default:
            return NULL;
    }


    return n;
}

// handle an operation
struct Node * make_operation(int operation, int nOfOperands, ... )
{
    va_list ap;
    struct Node *n;
    size_t nodeSize;

    int i;

    /* allocate node */
    nodeSize = SIZEOF_NODETYPE + sizeof(OperationNodeType) + (nOfOperands - 1) * sizeof(struct Node*);

    if ((n = malloc(nodeSize)) == NULL)
        yyerror("out of memory");

    /* copy information */
    n->type = OPERATION;
    n->opr.operation = operation;
    n->opr.noOfOperands = nOfOperands;

    va_start(ap, nOfOperands);
    for (i = 0; i < nOfOperands; i++)
        n->opr.op[i] = va_arg(ap, struct Node*);
    va_end(ap);

    return n;
}

// free the memory occupied by a given tree
void free_node(struct Node * n)
{
    if (!n) return;

    int i;
    if (n->type == OPERATION)
    {
        for (i = 0; i < n->opr.noOfOperands; i++)
        free_node(n->opr.op[i]);
    }

    free (n);
}

// check if the varialbe exits, or
// create a new entry in hashtable and save the reference to it
void variableHandler(char yytext[], char isConst, char def)
{
    struct Symbol * temp;

    // look up the symbol table
    HASH_FIND_STR(symbolTable, yytext, temp);

    if (!temp && def == 1)
    {
        // create an entry for the variable
        temp = ( struct Symbol*)malloc(sizeof( struct Symbol));

        temp->name = newstr(yytext);
        temp->isConst = isConst;

        // add to hashtable
        HASH_ADD_STR( symbolTable, name, temp );
    }
    else if (!temp && def != 1)
    {
        // check for a more global defination

        int length = strlen(yytext);
        char * global = newstr(yytext);
        global[length-1] = '0';
        global[length-2] = '1';
        global[length-3] = '0';

        // look up the symbol table
        HASH_FIND_STR(symbolTable, global, temp);
        //yyerror(global);
        if (!temp)
            yyerror("undeclared variable, first use in scope");
        else
            strcpy(yytext, global);
    }
    else if (temp)
    {

        // check the constants
        if (def == 0 && temp->isConst == 1)
        {
            yyerror("attempt to assign a const variable");
        }
        else if (def == 1)
        {
            yyerror("variable alread defined in the scope");
        }
    }
}

// read char data from a string
// eg: "'4'" = '4'
char validate_char(char * yytext)
{
    if (strlen(yytext) > 3)
    {
        // check for allawable escaped chars
        switch (yytext[2])
        {
            case 'n':
                return '\n';
            case 't':
                return '\t';
            case '\'':
                return '\'';
            case '\\':
                return '\\';
            case '\/':
                return '\/';
            case '\"':
                return '\"';
            case '0':
                return '\0';
            case 'r':
                return '\r';
            case 'b':
                return '\b';

            default:
                return '\0';
                yyerror("undefinded character literal.");

        }
    }
    else
    {
        return yytext[1];
    }
}


// print the symbol table as a datasegment
void make_dataSegment()
{

    print_hashTable();
}

void print_hashTable()
{
    struct Symbol *s;

    printf("\n.data\n");
    for(s=symbolTable; s != NULL; s=s->hh.next) {
        printf("%s dd ?\n", s->name);
    }
}

// generate the code given by the tree root node tree
// and clean that tree
void make_codeSegment(struct Node * tree)
{

    //printTree(tree,0,0,1,0);
    generate_code(tree);
    free_node(tree);
}

int
main(int argc, char * argv[])
{
    #if YYDEBUG
        yydebug = 1;
    #endif
    FILE * input_file = fopen(argv[1], 'r');
    FILE * output_file = fopen(argv[2], 'w');
    yyset_in (input_file );
    yyset_out (output_file )

    memset(scopes,0,sizeof(scopes));
    printf("#c-- compiler\n");
    if (yyparse() ==0)
        make_dataSegment();
    return 0;
}

yyerror(msg)
char *msg;
{
  fprintf(stderr, "%d: %s\n", yylineno, msg);
  exit(1);
}

int
yywrap()
{
  return(1);
}
