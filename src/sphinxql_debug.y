%{
#if _WIN32
#pragma warning(push,1)
#pragma warning(disable:4702) // unreachable code
#endif

#ifdef __GNUC__
#pragma GCC diagnostic ignored "-Wfree-nonheap-object"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#endif
%}

%lex-param	{ struct SqlDebugParser_c * pParser }
%parse-param	{ struct SqlDebugParser_c * pParser }
%pure-parser
%error-verbose

%union {
	int64_t iValue;
	float fValue;
	BlobLocator_t sValue;
}

%token <sValue>	TOK_QUOTED_STRING
%token <fValue> TOK_CONST_FLOAT
%token <iValue> TOK_CONST_INT
%token <iValue> TOK_USEC_INT
%token <sValue> TOK_IDENT
%token <sValue> TOK_USERVAR
%token <sValue> TOK_SYSVAR
%token <sValue> TOK_ON
%token <sValue> TOK_OFF
%token <sValue> TOK_INTO
%token <sValue> TOK_FROM
%token <sValue> TOK_CHUNK

%token <sValue>	TOK_STATUS
%token <sValue>	TOK_DEBUG
%token <sValue>	TOK_SHUTDOWN
%token <sValue>	TOK_CRASH
%token <sValue>	TOK_TOKEN
%token <sValue>	TOK_MALSTATS
%token <sValue>	TOK_MALTRIM
%token <sValue>	TOK_PROCDUMP
%token <sValue>	TOK_SETGDB
%token <sValue>	TOK_SLEEP
%token <sValue>	TOK_TASKS
%token <sValue>	TOK_SCHED
%token <sValue>	TOK_MERGE
%token <sValue>	TOK_DROP
%token <sValue>	TOK_FILES
%token <sValue>	TOK_OPTION
%token <sValue>	TOK_CLOSE
%token <sValue>	TOK_COMPRESS
%token <sValue>	TOK_SPLIT
%token <sValue>	TOK_WAIT
%token <sValue>	TOK_LIKE
%token <sValue>	TOK_META
%token <sValue>	TOK_TRACE
%token <sValue> TOK_CURL

%type <iValue> boolpar timeint
%type <sValue> ident szparam ident_special szparam_special

%%

debugclause:
	TOK_DEBUG debugcommand optsemicolon
	;

optsemicolon:
	| ';'
	;

debugcommand:
	shutdown_crash_token
	| malstats		{ pParser->m_tCmd.m_eCommand = Cmd_e::MALLOC_STATS; }
	| TOK_MALTRIM	{ pParser->m_tCmd.m_eCommand = Cmd_e::MALLOC_TRIM; }
	| TOK_PROCDUMP  { pParser->m_tCmd.m_eCommand = Cmd_e::PROCDUMP; }
	| TOK_CLOSE		{ pParser->m_tCmd.m_eCommand = Cmd_e::CLOSE; }
	| setgdb
	| sleep			{ pParser->m_tCmd.m_eCommand = Cmd_e::SLEEP; }
	| TOK_TASKS		{ pParser->m_tCmd.m_eCommand = Cmd_e::TASKS; }
	| TOK_SCHED		{ pParser->m_tCmd.m_eCommand = Cmd_e::SCHED; }
	| merge			{ pParser->m_tCmd.m_eCommand = Cmd_e::MERGE; }
	| drop			{ pParser->m_tCmd.m_eCommand = Cmd_e::DROP; }
	| files			{ pParser->m_tCmd.m_eCommand = Cmd_e::FILES; }
	| compress		{ pParser->m_tCmd.m_eCommand = Cmd_e::COMPRESS; }
	| split			{ pParser->m_tCmd.m_eCommand = Cmd_e::SPLIT; }
	| wait
	| TOK_META		{ pParser->m_tCmd.m_eCommand = Cmd_e::META; }
	| trace			{ pParser->m_tCmd.m_eCommand = Cmd_e::TRACE; }
	| curl			{ pParser->m_tCmd.m_eCommand = Cmd_e::CURL; }
	;

//////////////////////////////////////////////////////////////////////////

ident_special:
	TOK_IDENT | TOK_DEBUG | TOK_SHUTDOWN | TOK_CRASH | TOK_TOKEN | TOK_MALSTATS | TOK_MALTRIM
	| TOK_PROCDUMP | TOK_CLOSE | TOK_SETGDB | TOK_SLEEP | TOK_SCHED | TOK_MERGE | TOK_FILES
	| TOK_STATUS | TOK_COMPRESS | TOK_SPLIT | TOK_WAIT | TOK_LIKE | TOK_CURL
	;

ident:
	ident_special | TOK_OPTION | TOK_ON | TOK_OFF;

//////////////////////////////////////////////////////////////////////////

like_filter:
	// empty
	| TOK_LIKE TOK_QUOTED_STRING		{ pParser->AddStrOption ( "like", $2 ); }
	;

// commands 'debug shutdown', 'debug crash', 'debug token'
shutdown_crash_token:
	sh_cr_tok szparam opt_option_clause { pParser->m_tCmd.m_sParam = pParser->StrFromBlob ($2); }
	;

sh_cr_tok:
	TOK_SHUTDOWN	{ pParser->m_tCmd.m_eCommand = Cmd_e::SHUTDOWN; }
	| TOK_CRASH	{ pParser->m_tCmd.m_eCommand = Cmd_e::CRASH; }
	| TOK_TOKEN	{ pParser->m_tCmd.m_eCommand = Cmd_e::TOKEN; }
	;

// command curl 'url'
curl:
	TOK_CURL szparam { pParser->m_tCmd.m_sParam = pParser->StrFromBlob ($2); }
	;

szparam_special:
	TOK_QUOTED_STRING
	| ident_special
	;

szparam:
	TOK_QUOTED_STRING
	| ident
	;

szparam_opt:
	// empty
	| szparam { pParser->m_tCmd.m_sParam = pParser->StrFromBlob ($1); }
	;

malstats:
	TOK_MALSTATS szparam_opt
	;

// command 'setgdb on/off/status'
setgdb:
	TOK_SETGDB boolpar
	{
		pParser->m_tCmd.m_eCommand = Cmd_e::SETGDB;
		pParser->m_tCmd.m_iPar1 = $2;
	}
	| TOK_SETGDB TOK_STATUS
	{
		pParser->m_tCmd.m_eCommand = Cmd_e::GDBSTATUS;
	}
	;

boolpar:
	TOK_ON		{ $$ = 1; }
	| '1'		{ $$ = 1; }
	| TOK_OFF	{ $$ = 0; }
	| '0'		{ $$ = 0; }
	;

// command 'sleep msec [option...]'
sleep:
	TOK_SLEEP timeint opt_option_clause
	{
		auto& tCmd = pParser->m_tCmd;
                tCmd.m_iPar1 = $2;
	}
	;

timeint:
	TOK_CONST_INT {$$ = $1*1000000;} // by default time is in seconds, convert to microseconds
	| TOK_USEC_INT
	;

// command 'merge <IDX> [chunk] X [into] [chunk] Y [option...]'
merge:
	TOK_MERGE ident chunk TOK_CONST_INT into chunk TOK_CONST_INT opt_option_clause
	{
		auto& tCmd = pParser->m_tCmd;
		tCmd.m_sParam = pParser->StrFromBlob ($2);
		tCmd.m_iPar1 = $4;
		tCmd.m_iPar2 = $7;
	}
	;
chunk:
	| TOK_CHUNK
	;

into:
	| TOK_INTO
	;

// command 'drop [chunk] X [from] <IDX> [option...]'
drop:
	TOK_DROP chunk TOK_CONST_INT from ident opt_option_clause
	{
		auto& tCmd = pParser->m_tCmd;
		tCmd.m_sParam = pParser->StrFromBlob ($5);
		tCmd.m_iPar1 = $3;
	}
	;

from:
	| TOK_FROM
	;

// command 'files <IDX> [option...]'
files:
	TOK_FILES ident opt_option_clause
	{
		auto& tCmd = pParser->m_tCmd;
		tCmd.m_sParam = pParser->StrFromBlob ($2);
	}
	;

// command 'compress <IDX> [chunk] N [option...]'
compress:
	TOK_COMPRESS ident chunk TOK_CONST_INT opt_option_clause
	{
		auto& tCmd = pParser->m_tCmd;
		tCmd.m_sParam = pParser->StrFromBlob ($2);
		tCmd.m_iPar1 = $4;
	}
	;

// command 'split <IDX> [chunk] N on @uservar [option...]'
split:
	TOK_SPLIT ident chunk TOK_CONST_INT TOK_ON TOK_USERVAR opt_option_clause
	{
		auto& tCmd = pParser->m_tCmd;
		tCmd.m_sParam = pParser->StrFromBlob ($2);
		tCmd.m_sParam2 = pParser->StrFromBlob ($6);
		tCmd.m_iPar1 = $4;
	}
	;

// command 'wait <CLUSTER> status [N] [like ...]'
wait:
	TOK_WAIT ident opt_status like_filter opt_option_clause
	{
		auto& tCmd = pParser->m_tCmd;
		if ( tCmd.m_eCommand!=Cmd_e::WAIT_STATUS)
			tCmd.m_eCommand = Cmd_e::WAIT;
    	tCmd.m_sParam = pParser->StrFromBlob ($2);
	}
	;

opt_status:
	// empty
	| TOK_STATUS TOK_CONST_INT
	{
		auto& tCmd = pParser->m_tCmd;
		tCmd.m_eCommand = Cmd_e::WAIT_STATUS;
		tCmd.m_iPar1 = $2;
	}
	;

opt_option_clause:
	// empty
	| option_clause
	;

option_clause:
	TOK_OPTION option_list
	;

option_list:
	option_item
	| option_list ',' option_item
	;

option_item:
	szparam_special			{ pParser->AddBoolOption ( $1 ); }
	| szparam_special '=' szparam_special	{ pParser->AddStrOption ( $1, $3 ); }
	| szparam_special '=' TOK_OPTION	{ pParser->AddStrOption ( $1, $3 ); }
	| szparam_special '=' TOK_ON		{ pParser->AddBoolOption ( $1, true ); }
	| szparam_special '=' TOK_OFF		{ pParser->AddBoolOption ( $1, false ); }
	| szparam_special '=' TOK_CONST_INT	{ pParser->AddIntOption ( $1, $3 ); }
	| szparam_special '=' TOK_USEC_INT	{ pParser->AddIntOption ( $1, $3 ); }
	| szparam_special '=' TOK_CONST_FLOAT	{ pParser->AddFloatOption ( $1, $3 ); }
	;

// command 'trace "/path/to/file" [soft_size]'
trace:
	TOK_TRACE trace_args
	;

trace_args:
	TOK_QUOTED_STRING opt_size
	{
		pParser->m_tCmd.m_sParam = pParser->StrFromBlob ($1);
	}
	| boolpar
	{
		pParser->m_tCmd.m_iPar1 = 0;
	}
	;

opt_size:
	// empty
	| TOK_CONST_INT
	{
		pParser->m_tCmd.m_iPar1 = $1;
	}
	;

%%

#if _WIN32
#pragma warning(pop)
#endif

