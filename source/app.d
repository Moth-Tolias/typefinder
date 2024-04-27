import std.stdio;
import std.json;
import std.algorithm;

void main()
{
	auto typeComboScores = findTypeComboScores();

	auto result = typeComboScores.sort!("a.score < b.score");
	for (ubyte i = 0; i < 10; ++i)
	{
		writeln(result[i]);
	}
}

TypeCombo[] typeCombinations() @safe pure nothrow
{
	TypeCombo[] result;

	for(TypeId firstTypeId = 0; firstTypeId < noOfTypes; ++firstTypeId)
	{
		for(TypeId secondTypeId = 0; secondTypeId < noOfTypes; ++secondTypeId)
		{
			immutable combo = TypeCombo(firstTypeId, secondTypeId);
			if (!canFind(result, combo))
			{
				result ~= combo;
			}
		}
	}

	return result;
}

TypeComboAndScore[] findTypeComboScores() @safe pure nothrow
{
	TypeComboAndScore[] scores;

	foreach(typeCombo; typeCombinations())
	{
		int score;
		foreach(Type type; types[0 .. noOfTypes])
		{
			auto e = effectiveness(type.id, typeCombo);
			if(e > 1)
			{
				score += 1;
			}
			if (e < 1)
			{
				score -= 1;
			}
		}

		scores ~= (TypeComboAndScore(typeCombo, score));
	}

	return scores;
}

Party findBestParty()
{
	TypeCombo[] typeCombinations;

	Party best;
	size_t count;
	writeln();
	foreach(TypeCombo combo1; typeCombinations)
	{
		foreach(TypeCombo combo2; typeCombinations)
		{
			foreach(TypeCombo combo3; typeCombinations)
			{
				foreach(TypeCombo combo4; typeCombinations)
				{
					foreach(TypeCombo combo5; typeCombinations)
					{
						foreach(TypeCombo combo6; typeCombinations)
						{
							auto party = Party(combo1, combo2, combo3, combo4, combo5, combo6);
							if (best.score > party.score)
							{
								best = party;
							}
						}
						++count;

						write("\r", count, best);
					}
				}
			}
		}
	}

	return best;
}


enum Effectiveness : float
{
	Regular = 1,
	WeakTo = 2,
	Resists = 0.5f,
	Immune = 0
}

alias TypeId = size_t;

enum maxNoOfTypes = 32;

struct Type
{
	string name;
	TypeId id;
	Effectiveness[maxNoOfTypes] defenses;
}

struct TypeComboAndScore
{
	TypeCombo combo;
	float score;
}

mixin template OrderlessStaticArray(alias T, alias maxLength)
{
	size_t length;
	T[maxLength] contents;

	invariant(length <= contents.length, "overflow");
	invariant
	{
		foreach(count, T element; contents[0 .. length])
		{
			assert(contents[0 .. length].countUntil(element) == count, "elements must be unique");
		}
	}

	this(in T[] elements...) @safe @nogc nothrow pure
	in(elements.length <= contents.length, "buffer overflow")
	{
		foreach(T element; elements)
		{
			if(!contents[0 .. length].canFind(element)) //drop non-unique
			{
				contents[length] = element;
				length += 1;
			}
		}
	}

	bool opEquals(in typeof(this) rhs) @safe @nogc nothrow const pure
	{
		bool ok = length == rhs.length;
		foreach(typeof(this.contents[0]) typeId; contents[0 .. length])
		{
			ok &= rhs.contents[0 .. length].canFind(typeId);
		}
		return ok;
	}
}

struct TypeCombo
{
	mixin OrderlessStaticArray!(TypeId, 2);

	string toString() @safe nothrow const pure
	{
		string result;
		foreach(TypeId typeId; contents[0 .. length])
		{
			result ~= types[typeId].name;
		}
		return result;
	}
}

struct Party
{
	mixin OrderlessStaticArray!(TypeCombo, 6);

	float score()
	{
		float result;
		foreach(TypeCombo combo; contents[0 .. length])
		{
			int[maxNoOfTypes] comboScore = 1;
			foreach(size_t i, Type attack; types[0 .. noOfTypes])
			{
				auto e = effectiveness(i, combo);
				if(e > 1)
				{
					comboScore[i] += 1;
				}
				if (e < 1)
				{
					//comboScore[i]score -= 1;
				}
			}

			long bepis = 1;
			foreach(int i; comboScore[0 .. noOfTypes])
			{
				bepis *= i;
			}
			result += bepis;
		}
		return result;
	}
}

float effectiveness(in TypeId attack, in TypeCombo defender) @safe @nogc nothrow pure
{
	float result = 1;

	foreach(TypeId id; defender.contents[0 .. defender.length])
	{
		immutable Type type = types[id];
		result *= type.defenses[attack];
	}

	return result;
}

private TypeId[string] nameToId;

immutable size_t noOfTypes;
immutable Type[maxNoOfTypes] types;
shared static this()
{
	auto jsonTypes = parseJSON(import("default.json"))["types"].arrayNoRef;

	size_t count;
	foreach(TypeId typeId, JSONValue jsonType; jsonTypes)
	{
		auto name = jsonType["name"].str;
		nameToId[name] = typeId;
		++count;
	}

	noOfTypes = count;

	Type[maxNoOfTypes] tempTypes;
	foreach(TypeId typeId, JSONValue jsonType; jsonTypes)
	{
		Type type;
		type.name = jsonType["name"].str;
		type.id = typeId;

		setTypeDefencesFromList(type, jsonType["resists"].arrayNoRef, Effectiveness.Resists);
		setTypeDefencesFromList(type, jsonType["weaknesses"].arrayNoRef, Effectiveness.WeakTo);
		setTypeDefencesFromList(type, jsonType["immunities"].arrayNoRef, Effectiveness.Immune);

		tempTypes[typeId] = type;
	}

	types = tempTypes;
}

private void setTypeDefencesFromList(ref Type type, in JSONValue[] jsonTypeList, in Effectiveness effectiveness)
{
	foreach(JSONValue jsonType; jsonTypeList)
	{
		auto typename = jsonType.str;
		auto typeId = nameToId[typename];
		type.defenses[typeId] = effectiveness;
	}
}
