#if defined _shope_included_
  #endinput
#endif
#define _shope_included_

/**
 * Get number of money earned during current round.
 *
 * @param iClient		Client index given.
  *
 * @error				Wrong number of arguments.
 * @return				Money earned during current round.
 */
native int GetMoneyEarned(int iClient);

public SharedPlugin __pl_shope =
{
	name = "shope",
	file = "shope.smx",
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shope_SetNTVOptional()
{
	MarkNativeAsOptional("GetMoneyEarned");
}
#endif