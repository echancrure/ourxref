/*****************************************************************************************************************/
/*                                  Copyright 2009 Midoan Software Engineering SolutionsLtd.                     */
/*             No part of this document may be reproduced in any manner without the express written authority of */
/*                                            Midoan Software Engineering Solutions Ltd.                         */
/*                       Midoan Software Engineering Solutions Ltd. 18 The Glen, Mortarstown, Carlow, Ireland    */
/*****************************************************************************************************************/
/* A FLEX grammar for SPARK Ada                                         */
/* alex ourxref.l -o ourxref_lex.c                                              */
/************************************************************************/

%option yylineno
%{
#include "string.h"
#include "stdlib.h"
#include "ctype.h"
#include "math.h"

void get_line_col(char *);
void read_up_to_DLETTER(FILE *);
int error_count;    //number of parsing errors

%}
/*do not comment the macros : lex does not like it.*/
DIGIT                   [0-9]
INTEGER                 ({DIGIT}{DIGIT}*)            
%%
([a-zA-Z0-9\!\£\$\\%\\^\&\(\)\-\+\_\=\[\]\{\}\;\'\@\#\~\,\.])*\.(ads|adb)   { yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                                                                             strcpy(yylval.id, yytext);
                                                                             //all the filenames mentionned in foo.xref are added to a binary tree of filenames (see binary_filename.c)
                                                                             // this structure is then checked during parsing of foo.bind in ada.y to see if a file mantionned in foo.bind should really be added to the queue of file code to analyse
                                                                             //if (!filenames_in_xref) filenames_in_xref = add_filename(filenames_in_xref, filenames_in_xref, create_filename_node(yylval.id));
                                                                             //else add_filename(filenames_in_xref, filenames_in_xref, create_filename_node(yylval.id));
                                                                             return(SOURCE_NAME);
                                                                           }
\"(\"\"|[^\n\"])*\"     {
                          yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                          strcpy(yylval.id, yytext);
                          return(ENTITY);       //a string to be more precise
                        }
"'"."'"                 {
                          yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                          strcpy(yylval.id, yytext);
                          return(ENTITY);       //a character literal to be more precise
                        }
\([^\)]*\)              {
                          yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                          strcpy(yylval.id, yytext);
                          return(BRACKETED);
                        }
\{[^\}]*\}              {
                          yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                          strcpy(yylval.id, yytext);
                          return(CURLY_BRACKETED);
                        }
\<[^\>]*\>              {
                          yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                          strcpy(yylval.id, yytext);
                          return(ANGLE_BRACKETED);
                        }
\[[^\]]*\]              {
                          yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                          strcpy(yylval.id, yytext);
                          return(SQUARE_BRACKETED);
                        }

{INTEGER}\              {
                          yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                          strcpy(yylval.id, yytext);
                          return(INTEGER);
                        }

{INTEGER}\|             {
                          yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                          strncpy(yylval.id, yytext, strlen(yytext)-1);
                          yylval.id[strlen(yytext)-1] = '\0';   //necessary because not automatic
                          return(FILENO);   //the index mentioned
                        }
\={INTEGER}.{INTEGER}     {
                          yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                          strcpy(yylval.id, yytext);
                          return(RENAME_REF);
                        }
{INTEGER}[a-z]([0-9]*[a-z]+)+([a-z0-9])*    { 
                                             return RUBBISH;
                                            }
{INTEGER}[a-zA-Z\>\<\=\^](\<.*\>)?{INTEGER}     {
                          get_line_col(yytext); // sets yylval.line, .letter and .column appropriately
                          return(LINE_CHAR_COL);
                        }

\n{INTEGER}.{INTEGER}     {
                          get_line_col(&yytext[1]); // sets yylval.line, .letter and .column appropriately
                          return(START_LINE_CHAR_COL);
                        }

[a-zA-Z](_?[a-zA-Z0-9])*    {
                              yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                              strcpy(yylval.id, yytext);
                              return(ENTITY);
                            }

([a-zA-Z0-9\!\£\$\\%\\^\&\(\)\-\+\_\=\[\]\{\}\;\'\@\#\~\,])*\.([a-zA-Z0-9\_])*  { yylval.id = malloc((strlen(yytext)+1)*sizeof(char));
                                                                  strcpy(yylval.id, yytext);
                                                                  return(SUBUNIT);
                                                                }
\n\X\                   {return(XLETTER);}
\n\D\                   {return(DLETTER);}
"*"                     {return(ASTERISK);}
\n\.                    {;}
[ \t\f]                 {;}
.                       {;}
%%
// standard lex function called automatically at the end of file being parsed
// re-written (normally only returns 1) to allow parsing of various input files
// parsing order:   1st standard.xref by default (see ada.y)
//                  2nd standard.ads
//                  3rd foo.xref is parsed next
//                  4th foo.bind is parsed next as created by gnatmake
//                              then code files according to elaboration order (including foo.ads)
int yywrap()
{
  char *ali_file;
  fclose(yyin);
  yylineno = 0;  //re-initialisation for new file
  ali_file = get_next_ali();
  if (ali_file) {
    yyin = fopen(ali_file, "r");
    if (!yyin) {
      fprintf(stderr, "OURXREF ERROR: %s:  Can't open internal file", ali_file);
      fflush(stderr);
      exit(212);
    }
    if (debugMode) fprintf(stderr, "Referencing : %s\n", ali_file);
    else fprintf(stderr, ".");
    read_up_to_DLETTER(yyin);
    return (0); //keep on trucking
  }
  else
    return (1); //no more files to parse
}//yywrap function

void get_line_col(char *text) // e.g. text 72e11 or 202b<c,__gnat_Unwind_ForcedUnwind>52
{
  int i = 0;
  while (isdigit(text[i])) {
    i++;
  }
  yylval.line_col.line = malloc((i)*sizeof(char));
  strncpy(yylval.line_col.line, text, i);
  yylval.line_col.line[i] = '\0';
  yylval.line_col.letter = text[i];
  if (text[i+1] == '<') {
    i++;
    while (text[i] != '>') {
      i++;
    }
  }
  yylval.line_col.column = malloc((strlen(&text[i+1])+1)*sizeof(char));
  strcpy(yylval.line_col.column, &text[i+1]);
}
//read all the rubbish up to the first DLetter
void read_up_to_DLETTER(FILE *f)
{ int ch;
  do {
    do {
      ;
    } while (fgetc(f) != '\n');
    yylineno++;
    ch = fgetc(f);
	if (ch == 'D') break;
    ungetc(ch, f);
  } while (1);
  ungetc('D', f);
  ungetc('\n', f);
}

/**************************************END OF ourxref.l FILE *********************************************/