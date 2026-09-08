#!/usr/bin/env python3
"""Generate magnify.json — the facet bank for the Magnify the Lord pillar.

Run from the repo root:

    python3 scripts/generate_magnify.py

Every `declaration` is copied VERBATIM out of declarationsv10.json, which is what
stops the bank and the reviewed library from drifting. The facets below are the
hand-authored half: a name of God, the same thing in plain English, and the line
spoken up to Him. Nine domains, fifteen each, ordered gentle to deep so the
intensity ladder (5/5/5) falls out of position.

Two rules the content must keep, both enforced by tests:
  · Every exaltation is addressed TO God, in the second person. This is what lets
    the pillar drop the CLAUDE.md rule 12 exception its predecessor needed.
  · Nothing names the low thing — not in an exaltation, not in an attribute, not
    in a domain raw value.
"""

import json
import re
from collections import Counter

# 9 domains x 15 facets. Ordered gentle -> deep, so intensity 1/2/3 falls out
# of position. Every exaltation is spoken TO God, second person, mouth-ready.
FACETS = {
 "peace": [
  ("Jehovah Shalom", "The Lord my peace", "You are my peace. You are the God who settles the storm."),
  ("My Shepherd's Rod", "The God who walks me through", "You walk with me through the valley. I fear nothing there."),
  ("My Refuge", "The God I run into", "You are my refuge. I run into Your name and I am safe."),
  ("My Shield", "The God who covers me", "You are my shield. You cover me on every side."),
  ("The Keeper Who Never Sleeps", "The God who watches all night", "You never sleep. You watch over me all night long."),
  ("The Lord Who Goes Before Me", "The God already there", "You go before me. You have already been where I am going."),
  ("My Rock", "The God who does not move", "You are my rock. You do not move, and neither does what You hold."),
  ("My Hiding Place", "The God I am hidden in", "You are my hiding place. I am hidden in You."),
  ("The Everlasting Arms", "The God underneath me", "Underneath me are Your everlasting arms. You do not let go."),
  ("The God of All Comfort", "The God who meets me here", "You are the God of all comfort. You meet me exactly where I am."),
  ("The God Who Stills the Sea", "Lord over every storm", "You speak, and the sea lies down. You are Lord over every storm."),
  ("The Lord of Hosts", "The God whose armies answer", "You are the Lord of Hosts. Heaven's armies answer to You."),
  ("The Lord My Banner", "The God who fights for me", "You are my banner. You fight for me and I hold my peace."),
  ("My Deliverer", "The God who has never lost", "You are my deliverer. You have never lost a battle."),
  ("Prince of Peace", "The God whose peace is not the world's", "You are the Prince of Peace. Your peace is not like the world's."),
 ],
 "grace": [
  ("The Lamb of God", "The God who finished it", "You are the Lamb of God. You took it all, and it is finished."),
  ("The God Rich in Mercy", "The God whose mercy is new", "You are rich in mercy. Your mercy is new every morning."),
  ("The Lifter of My Head", "The God who raises me up", "You are the lifter of my head. You raise me up."),
  ("My Redeemer", "The God who bought me back", "You are my Redeemer. You bought me at full price."),
  ("The God of All Grace", "The God whose grace is enough", "You are the God of all grace. Your grace is more than enough."),
  ("The God Who Remembers No More", "The God who buried it", "You remember my sin no more. You threw it into the sea."),
  ("My Advocate", "The God who speaks for me", "You are my Advocate. You speak for me before the Father."),
  ("My High Priest", "The God who always intercedes", "You are my High Priest. You always live to intercede for me."),
  ("The God Who Casts It Far", "The God who removed it", "You removed it as far as the east is from the west."),
  ("The Fountain Opened", "The God who washes me", "You are the fountain opened for me. You wash me clean."),
  ("The God Who Justifies", "The God who calls me righteous", "You are the God who justifies. You call me righteous and it is so."),
  ("My Ransom", "The God who paid it all", "You are my ransom. You paid what I could never pay."),
  ("The God Who Restores the Years", "The God who gives it back", "You restore what was lost. You give back the years."),
  ("The Breaker", "The God every chain answers", "You are the Breaker. Every chain gives way at Your name."),
  ("The Author and Finisher", "The God who completes it", "You are the author and the finisher. You complete what You began."),
 ],
 "provision": [
  ("Jehovah Jireh", "The God who sees ahead and provides", "You are Jehovah Jireh. You see ahead and You provide."),
  ("My Shepherd", "The God I lack nothing under", "You are my Shepherd. I lack nothing."),
  ("The Giver of Every Good Gift", "The God who does not run out", "Every good gift comes from You. You do not run out."),
  ("The God Who Opens His Hand", "The God who satisfies", "You open Your hand and satisfy every living thing."),
  ("The God Who Sets a Table", "The God who prepares it Himself", "You set a table for me. You prepare it Yourself."),
  ("My Portion", "The God who is enough", "You are my portion. You are more than enough."),
  ("The God Who Supplies", "The God who meets every need", "You supply all my need out of Your riches in glory."),
  ("The Owner of a Thousand Hills", "The God who is short of nothing", "The cattle on a thousand hills are Yours. You are short of nothing."),
  ("The Lord of the Harvest", "The God who multiplies", "You are the Lord of the harvest. You multiply what is sown."),
  ("The God Who Rains Bread from Heaven", "The God who feeds me daily", "You rain bread from heaven. You feed me morning by morning."),
  ("The God Who Fills the Empty Jars", "The God who fills till there is no room", "You fill what is empty. You fill it until there is no room left."),
  ("The God Who Opens Doors", "The God no one can shut out", "You open doors no one can shut."),
  ("The God Whose Blessing Adds No Sorrow", "The God who makes rich", "Your blessing makes rich and adds no sorrow to it."),
  ("The Owner of Silver and Gold", "The God who gives freely", "The silver and the gold are Yours. You give freely."),
  ("The God Who Builds the House", "The God who watches the city", "You build the house. You watch over the city."),
 ],
 "belonging": [
  ("The God Who Calls Me by Name", "The God who knows me", "You call me by name. I am Yours."),
  ("The God Who Sees Me", "The God I am not overlooked by", "You are the God who sees me. I am not overlooked."),
  ("The Father Who Chose Me", "The God who wanted me first", "You chose me before the world was made."),
  ("The Friend Who Stays", "The God closer than a brother", "You are the Friend who stays closer than a brother."),
  ("The God Who Adopted Me", "The God who made me family", "You adopted me. I belong to Your household forever."),
  ("The God Who Runs to Meet Me", "The God who does not wait", "You run to meet me. You do not wait for me to arrive."),
  ("The God Who Sets the Lonely in Families", "The God who gives me a people", "You set the lonely in families. You give me a people."),
  ("The Shepherd Who Leaves the Ninety-Nine", "The God who came for one", "You leave the ninety-nine for one. You came for me."),
  ("The God Who Engraved Me on His Hands", "The God who cannot forget me", "You engraved me on the palms of Your hands."),
  ("The Head of the Body", "The God who joined me to His own", "You are the Head, and I am joined to Your body. I am not on my own."),
  ("The God Whose Love Never Fails", "The God whose love has no condition", "Your love never fails. It has no end and no condition."),
  ("The God Who Rejoices Over Me", "The God who is glad about me", "You rejoice over me with gladness. You quiet me with Your love."),
  ("The Bridegroom", "The God who delights in me", "You are the Bridegroom. You delight over me with singing."),
  ("The Firstborn Among Many", "The God who calls me family", "You are the firstborn among many. You call me family."),
  ("The God Nothing Can Separate Me From", "The God who made me His own", "You made me Your own. Nothing can separate me from Your love."),
 ],
 "healing": [
  ("Jehovah Rapha", "The God who heals", "You are Jehovah Rapha. You are the God who heals."),
  ("The God Who Knit Me Together", "The God who knows this body", "You knit me together. You know every part of this body."),
  ("The Life-Giver", "The God whose life is in me", "You are the life-giver. Your life is in every part of me."),
  ("The Great Physician", "The God nothing is hidden from", "You are the Great Physician. Nothing is hidden from You."),
  ("The God Who Renews My Strength", "The God who lifts me up", "You renew my strength. I rise up on wings like eagles."),
  ("The Lord Who Forgives and Heals", "The God who does both", "You forgive all my sin and heal all my disease."),
  ("The God Who Sends His Word and Heals", "The God whose word works", "You send Your word and it heals. Your word never comes back empty."),
  ("The Sun of Righteousness", "The God who rises with healing", "You rise with healing in Your wings."),
  ("The God of Wholeness", "The God who leaves nothing half done", "You make whole. You leave nothing half done."),
  ("The God Who Restores Health", "The God who brings it back", "You restore my health. You bring back what was taken."),
  ("The Breath of Life", "The God whose breath is in me", "You breathe, and life comes. Your breath is in me."),
  ("The God Who Carried It All", "The God who took it in my place", "You carried it all in Your own body. You left me nothing to carry."),
  ("The God Whose Wounds Healed Me", "The God who already did it", "By Your wounds I am healed. It is already done."),
  ("The God Who Satisfies with Long Life", "The God who gives length of days", "You satisfy me with long life and show me Your salvation."),
  ("The God Who Raises the Dead", "The God nothing is too far gone for", "You raise the dead. Nothing is too far gone for You."),
 ],
 "identity": [
  ("My Maker", "The God who does not make mistakes", "You are my Maker. You do not make mistakes."),
  ("The Potter", "The God whose hands made me", "You are the Potter. I am the work of Your hands."),
  ("The God Who Delights in Me", "The God who settles who I am", "You delight in me. That settles who I am."),
  ("The God Who Crowns Me", "The God who puts love on my head", "You crown me with love and compassion."),
  ("The God Who Knew Me Before the Womb", "The God who set me apart", "You knew me before You formed me. You set me apart."),
  ("The Author of My Days", "The God who wrote them first", "You wrote all my days before one of them was."),
  ("The God Who Lifts the Lowly", "The God who seats me with princes", "You lift the lowly and seat them with princes."),
  ("The God Who Gave Me a New Name", "The God the old name lost to", "You gave me a new name. The old one has no hold."),
  ("The God Who Chose the Overlooked", "The God who always has", "You choose the overlooked. You always have."),
  ("The God Who Finishes What He Starts", "The God who will complete me", "You finish what You start. You will complete this in me."),
  ("My Righteousness", "The God I stand in", "You are my righteousness. I stand in Yours, not mine."),
  ("The God Whose Spirit Lives in Me", "The God who is greater", "Your Spirit lives in me. Greater is He who is in me."),
  ("The King Who Made Me His Own", "The God whose house I belong to", "You are King, and You made me Your own."),
  ("The God Who Calls Things That Are Not", "The God who speaks it into being", "You call things that are not as though they already are."),
  ("The God Who Sees What I Already Am", "The God who sees the finished work", "You see who I already am in You."),
 ],
 "nearness": [
  ("Immanuel", "God with me", "You are Immanuel. God with me, right here."),
  ("The God Who Hears", "The God who turns His ear", "You hear me. You turn Your ear to me."),
  ("The God Who Never Leaves", "The God who does not go", "You never leave me. You never forsake me."),
  ("The God Close to the Brokenhearted", "The God who is near", "You are close to the brokenhearted. You are near."),
  ("The Comforter", "The God who came to stay", "You are the Comforter. You came to be with me and stay."),
  ("The God Who Restores My Soul", "The God who leads me to still water", "You restore my soul. You lead me beside still waters."),
  ("The God Whose Mercies Are New", "The God faithful every morning", "Your mercies are new every morning. Great is Your faithfulness."),
  ("The God Who Keeps My Tears", "The God who wastes nothing", "You keep every tear in Your bottle. Not one is wasted."),
  ("The God Who Sings Over Me", "The God who quiets me", "You sing over me. You quiet me with Your love."),
  ("The God of Hope", "The God who fills me", "You are the God of hope. You fill me with joy and peace."),
  ("My Dwelling Place", "The God I live in", "You are my dwelling place. I live in You."),
  ("The Bright Morning Star", "The God morning always comes with", "You are the bright morning star. Morning always comes."),
  ("The God Who Is My Rest", "The God who carries it", "You are my rest. In You I am not carrying it."),
  ("The God Who Wipes Every Tear", "The God who ends it well", "You will wipe every tear from my eyes."),
  ("The God Who Walks With Me Through It", "The God in the fire", "You walk with me through the fire. You do not send me alone."),
 ],
 "clarity": [
  ("My Counselor", "The God who tells me the way", "You are my Counselor. You tell me which way to go."),
  ("The Light of the World", "The God I see by", "You are the Light of the World. In Your light I see."),
  ("A Lamp to My Feet", "The God who lights the next step", "Your word is a lamp to my feet and a light to my path."),
  ("The God Who Gives Wisdom Generously", "The God who finds no fault", "You give wisdom generously and without finding fault."),
  ("The God Who Orders My Steps", "The God who straightens the path", "You order my steps. You make the path straight."),
  ("The God Who Speaks", "The God whose voice I know", "You speak, and I know Your voice."),
  ("The Spirit of Truth", "The God who guides me into all of it", "You are the Spirit of Truth. You guide me into all truth."),
  ("The God Who Makes a Way", "The God who opens what is closed", "You make a way where there is none."),
  ("The God Who Reveals Deep Things", "The God who sees in the dark", "You reveal deep and hidden things. You know what is in the dark."),
  ("The Cornerstone", "The God everything lines up to", "You are the cornerstone. Everything lines up to You."),
  ("The God of Limitless Understanding", "The God who misses nothing", "Your understanding has no limit. You miss nothing."),
  ("The God Who Holds Tomorrow", "The God I trust it with", "You hold tomorrow. I do not have to see it to trust You with it."),
  ("The Alpha and Omega", "The God who knows the end", "You are the Alpha and Omega. You already know the end."),
  ("The God Who Is Never Confused", "The God who holds it together", "You are never confused. You hold all of it together."),
  ("The God Who Finishes the Story", "The God who ends it well", "You are writing this, and You finish every story well."),
 ],
 "purity": [
  ("The God Who Makes Clean", "The God whose washing holds", "You make clean. What You wash stays washed."),
  ("The Living Water", "The God who ends the thirst", "You are living water. I drink and I am never thirsty again."),
  ("The Bread of Life", "The God who is what I actually want", "You are the bread of life. You are what I actually want."),
  ("The God Who Satisfies", "The God of fullness of joy", "You satisfy me. In Your presence is fullness of joy."),
  ("The God Who Gives a New Heart", "The God who puts a new spirit in me", "You give me a new heart. You put a new spirit in me."),
  ("The God Who Sets Free", "The God whose freedom is real", "Whom You set free is free indeed."),
  ("The God Who Washes Whiter Than Snow", "The God who leaves no stain", "You wash me whiter than snow."),
  ("The God Who Renews My Mind", "The God whose thoughts become mine", "You renew my mind. Your thoughts become mine."),
  ("The God Who Makes a Way Out", "The God who is faithful every time", "You always make a way out. You are faithful."),
  ("The God Who Broke Every Chain", "The God who says I am free", "You broke every chain. I am free because You say so."),
  ("The God Who Sanctifies", "The God who will do it", "You sanctify me completely. You are faithful and You will do it."),
  ("The Consuming Fire", "The God nothing false survives", "You are a consuming fire. Nothing false survives Your presence."),
  ("The Holy One", "The God whose holiness is my gift", "You are the Holy One. Holiness is Your gift to me."),
  ("The God Who Restores Clean Hands", "The God who gives it back", "You give back what was taken. You restore clean hands and a clean heart."),
  ("The God Who Keeps Me from Falling", "The God who presents me blameless", "You are able to keep me from falling and present me blameless."),
 ],
}

# Where each domain draws its declarations from, best first. Mirrors
# MagnifyDomain.declarationCategories in Magnify.swift.
SOURCES = {
 "peace":     ["fear", "anxiety", "godsprotection", "rest"],
 "grace":     ["grace", "forgiveness", "addiction", "salvation"],
 "provision": ["wealth", "debt", "housing", "work", "business"],
 "belonging": ["love", "friendship", "innerHealing", "marriage"],
 "healing":   ["health", "wellness", "mentalHealth", "fertility"],
 "identity":  ["identity", "confidence", "destiny", "favor"],
 "nearness":  ["hope", "innerHealing", "rest", "grief", "godsheart"],
 "clarity":   ["wisdom", "faith", "destiny", "miracles"],
 "purity":    ["purity", "addiction"],
}

# The teaching layer. One shows on BEHOLD each day, rotating, so the "why"
# accrues over months instead of being a wall dismissed once.
WHY_LINES = [
 "Whatever you magnify, you get more of.",
 "A telescope never moved a mountain. It just filled your eyes with it.",
 "Magnifying doesn't make God bigger. It makes Him bigger to you.",
 "Mary said this while her whole life looked ruined.",
 "Paul and Silas sang at midnight, in chains. The foundations moved after.",
 "Jehoshaphat sent the worshippers out ahead of the army.",
 "David lost everything at Ziklag, and strengthened himself in the Lord.",
 "Praise is what you do before the walls come down, not after.",
 "You will not out-think this. You can out-worship it.",
 "The size of the storm never changed. The size of your God did.",
 "You become what you behold.",
 "Nothing gets smaller by staring at it. Look higher instead.",
 "Worship is not a feeling you wait for. It is a thing you do first.",
 "Whatever fills your eyes sets the size of your day.",
 "He was already this big. Today you get to see it.",
 "Job worshipped on the worst day of his life, before one thing was restored.",
 "The disciples woke Jesus in the storm. He was bigger than it the whole time.",
 "Habakkuk had no figs, no flock, no herd. He said he would rejoice anyway.",
 "You are not talking yourself into anything. You are agreeing with what is.",
 "Speak it out loud. Faith comes by hearing, and your own ears count.",
 "Magnify Him first, and everything else finds its actual size.",
 "This is not denial. It is putting the truth where your eyes are.",
 "Peter looked at the wind and sank. He was looking at the wrong thing.",
 "Every one of them magnified God before anything changed.",
]

SRC = 'SpeakLife/SpeakLife/Preview Content/AffirmationData/declarationsv10.json'
OUT = 'SpeakLife/SpeakLife/Preview Content/AffirmationData/magnify.json'

decls = json.load(open(SRC))['declarations']
by_cat = {}
for i, d in enumerate(decls):
    by_cat.setdefault(d['category'], []).append((i, d))

FIRST_PERSON = re.compile(r"\b(I|I'm|my|me|mine)\b", re.I)

def usable(d):
    t = d.get('text', '')
    if not t or not d.get('bibleVerseText') or not d.get('book'):
        return False
    if '—' in t or '–' in t:          # CLAUDE.md rule 7
        return False
    words = t.split()
    if not (8 <= len(words) <= 22):    # rule 13: compressed, mouth-ready
        return False
    return bool(FIRST_PERSON.search(t))  # rule 1: first person only

used_books = set()
used_texts = set()
entries = []

for domain, facets in FACETS.items():
    pool = []
    for cat in SOURCES[domain]:
        for i, d in sorted(by_cat.get(cat, []), key=lambda p: p[0]):
            if usable(d):
                pool.append(d)
    picked = []
    # Pass 1: books unused anywhere in the bank (rule 3, applied bank-wide).
    for d in pool:
        if len(picked) == 15:
            break
        if d['book'] in used_books or d['text'] in used_texts:
            continue
        used_books.add(d['book']); used_texts.add(d['text'])
        picked.append(d)
    # Pass 2: relax to book-unique-within-domain if the category ran dry.
    if len(picked) < 15:
        domain_books = {d['book'] for d in picked}
        for d in pool:
            if len(picked) == 15:
                break
            if d['text'] in used_texts or d['book'] in domain_books:
                continue
            used_texts.add(d['text']); domain_books.add(d['book'])
            picked.append(d)
    assert len(picked) == 15, f"{domain}: only {len(picked)} declarations"

    for n, (facet, decl) in enumerate(zip(facets, picked)):
        name, attribute, exaltation = facet
        entries.append({
            "id": f"magnify_{domain}_{n+1:03d}",
            "domain": domain,
            # 5 per level, gentle -> deep, so the ladder falls out of order.
            "intensity": n // 5 + 1,
            "nameOfGod": name,
            "attribute": attribute,
            "exaltation": exaltation,
            "declaration": decl['text'],
            "verseText": decl['bibleVerseText'],
            "book": decl['book'],
            "declarationCategory": decl['category'],
        })

bank = {"version": 1, "whyLines": WHY_LINES, "entries": entries}
with open(OUT, 'w') as f:
    json.dump(bank, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f"wrote {len(entries)} entries -> {OUT}")
from collections import Counter
print(Counter(e['domain'] for e in entries))
print(Counter(e['intensity'] for e in entries))
print("unique books:", len({e['book'] for e in entries}), "unique declarations:", len({e['declaration'] for e in entries}))
