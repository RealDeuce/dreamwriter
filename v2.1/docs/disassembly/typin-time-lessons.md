# Typin' Time Lesson Text

This is a reference dump of the two lesson banks reached by the
Typin' Time test-selection grid. The pointer table starts at
`F50E:275C` / file `0x7783C` and is split into two banks separated
by `0x7BC` bytes.

Each menu cell is `0x3C` bytes, or 15 far-pointer slots. Slot 0 is
the menu label. Later slots point to displayed practice lines and then
to a NUL string terminator; unused slots are zero far pointers.

## Typin' Write Bank

### 01. `A1`

Cell: file `0x7783C`; label pointer `F50E:0002`.

- `F50E:0005`: We went to the store.
- `F50E:001B`: `<NUL terminator>`

### 02. `A2`

Cell: file `0x77878`; label pointer `F50E:001C`.

- `F50E:001F`: The things were alive.
- `F50E:0036`: `<NUL terminator>`

### 03. `A3`

Cell: file `0x778B4`; label pointer `F50E:0037`.

- `F50E:003A`: Some were very small.
- `F50E:0050`: `<NUL terminator>`

### 04. `B1`

Cell: file `0x778F0`; label pointer `F50E:0051`.

- `F50E:0054`: All the flowers were red and white.
- `F50E:0078`: `<NUL terminator>`

### 05. `B2`

Cell: file `0x7792C`; label pointer `F50E:0079`.

- `F50E:007C`: There were fifty figs in the basket.
- `F50E:00A1`: `<NUL terminator>`

### 06. `B3`

Cell: file `0x77968`; label pointer `F50E:00A2`.

- `F50E:00A5`: You should have been there with me.
- `F50E:00C9`: `<NUL terminator>`

### 07. `C1`

Cell: file `0x779A4`; label pointer `F50E:00CA`.

- `F50E:00CD`: Get the games out, the guys are coming over.
- `F50E:00FA`: `<NUL terminator>`

### 08. `C2`

Cell: file `0x779E0`; label pointer `F50E:00FB`.

- `F50E:00FE`: We can have a race to see which one goes faster.
- `F50E:012F`: `<NUL terminator>`

### 09. `C3`

Cell: file `0x77A1C`; label pointer `F50E:0130`.

- `F50E:0133`: Funny things, with floppy wings, were flying all around us.
- `F50E:016F`: `<NUL terminator>`

### 10. `D1`

Cell: file `0x77A58`; label pointer `F50E:0170`.

- `F50E:0173`: You can have some of my fries if I can have all your ice cream.
- `F50E:01B3`: `<NUL terminator>`

### 11. `D2`

Cell: file `0x77A94`; label pointer `F50E:01B4`.

- `F50E:01B7`: We have robots to clean our rooms for us and you should have one 
- `F50E:01F9`: too.
- `F50E:01FE`: `<NUL terminator>`

### 12. `D3`

Cell: file `0x77AD0`; label pointer `F50E:01FF`.

- `F50E:0202`: With red teeth, yellow beards and great green ears, they looked a 
- `F50E:0245`: little odd.
- `F50E:0251`: `<NUL terminator>`

### 13. `E1`

Cell: file `0x77B0C`; label pointer `F50E:0252`.

- `F50E:0255`: A moose on the loose in the house we could handle, but a skunk 
- `F50E:0295`: would be no fun at all.
- `F50E:02AD`: `<NUL terminator>`

### 14. `E2`

Cell: file `0x77B48`; label pointer `F50E:02AE`.

- `F50E:02B1`: We chased it, we trapped it, but we were too scared to catch it, 
- `F50E:02F3`: so we decided to let it go.
- `F50E:030F`: `<NUL terminator>`

### 15. `F1`

Cell: file `0x77B84`; label pointer `F50E:0310`.

- `F50E:0313`: Those four are really good skiers, but the rest of us are just 
- `F50E:0353`: here for the fun of it.  We spend most of our time out of 
- `F50E:038E`: control, tripping over each other.
- `F50E:03B1`: `<NUL terminator>`

### 16. `F2`

Cell: file `0x77BC0`; label pointer `F50E:03B2`.

- `F50E:03B5`: In the summer we all go fishing together.  The biggest fish we 
- `F50E:03F5`: ever hooked was so strong that it pulled us out to sea and we 
- `F50E:0434`: were forced to cut the line.
- `F50E:0451`: `<NUL terminator>`

### 17. `G1`

Cell: file `0x77BFC`; label pointer `F50E:0452`.

- `F50E:0455`: First they made silly faces.  Then they made funny noises.  
- `F50E:0492`: Then they started jumping up and down, waving their arms 
- `F50E:04CC`: and throwing peanuts in the air.  And the animals thought 
- `F50E:0507`: to themselves that human beings really are very strange 
- `F50E:0540`: creatures.
- `F50E:054B`: `<NUL terminator>`

### 18. `G2`

Cell: file `0x77C38`; label pointer `F50E:054C`.

- `F50E:054F`: We had a great time at the beach last week.  During the 
- `F50E:0588`: day, the waves were big enough for surfing and, when it 
- `F50E:05C1`: rained, we fished off the pier.  At night, we walked 
- `F50E:05F7`: on the sand with our flashlights and tried to catch 
- `F50E:062C`: fiddler crabs.  You should come with us next time.
- `F50E:065F`: `<NUL terminator>`

### 19. `P-AS`

Cell: file `0x77C74`; label pointer `F50E:0660`.

- `F50E:0665`: sad was sat sea save star cast cars rats races 
- `F50E:0695`: washing the cats 
- `F50E:06A7`: was not as easy as 
- `F50E:06BB`: washing the cars.
- `F50E:06CD`: `<NUL terminator>`

### 20. `P-CV`

Cell: file `0x77CB0`; label pointer `F50E:06CE`.

- `F50E:06D3`: cat vet cave cab vest carve crave vacate excavate 
- `F50E:0706`: cats crave chips and gravy, 
- `F50E:0723`: crabs go crazy over clover.  
- `F50E:0741`: cats have nine lives, crabs have five.
- `F50E:0768`: `<NUL terminator>`

### 21. `P-ER`

Cell: file `0x77CEC`; label pointer `F50E:0769`.

- `F50E:076E`: red were ear are read care race craze react freeze 
- `F50E:07A2`: their eyes were red, 
- `F50E:07B8`: their ears were green.  
- `F50E:07D1`: they were really scary.
- `F50E:07E9`: `<NUL terminator>`

### 22. `P-IO`

Cell: file `0x77D28`; label pointer `F50E:07EA`.

- `F50E:07EF`: oil lion join kilo loin oily onion hippo pill poll 
- `F50E:0823`: noisy tigers look like lions, 
- `F50E:0842`: tigers like boiling onions.  
- `F50E:0860`: lions like cooler food.
- `F50E:0878`: `<NUL terminator>`

### 23. `P-KL`

Cell: file `0x77D64`; label pointer `F50E:0879`.

- `F50E:087E`: hulk milk link look kilo milky yolk plink plonk 
- `F50E:08AF`: it was black and prickly, 
- `F50E:08CA`: but it blinked and talked 
- `F50E:08E5`: when we tickled it.
- `F50E:08F9`: `<NUL terminator>`

### 24. `P-NM`

Cell: file `0x77DA0`; label pointer `F50E:08FA`.

- `F50E:08FF`: him moon mink no monk my hymn mop pin 
- `F50E:0926`: jam on my hands 
- `F50E:0937`: is more fun than 
- `F50E:0949`: ham on a bun.
- `F50E:0957`: `<NUL terminator>`

### 25. `P-PUNCT`

Cell: file `0x77DDC`; label pointer `F50E:0958`.

- `F50E:0960`: no, no, no.  no moo, no milk.  my, oh, my.  no oil, ink only.  
- `F50E:09A0`: do, re, mi, fa, sol, la, ti, do, 
- `F50E:09C2`: do.  re.  mi.  fa.  sol.  la.  ti.  do.  
- `F50E:09EC`: do, re.  mi, fa.  sol, la.  ti, do.
- `F50E:0A10`: `<NUL terminator>`

### 26. `P-RT`

Cell: file `0x77E18`; label pointer `F50E:0A11`.

- `F50E:0A16`: rat star raft rate stare trace cart great crate react 
- `F50E:0A4D`: there were three tired rats.  
- `F50E:0A6C`: the first two tripped, 
- `F50E:0A84`: the third tried trotting.
- `F50E:0A9E`: `<NUL terminator>`

### 27. `P-SD`

Cell: file `0x77E54`; label pointer `F50E:0A9F`.

- `F50E:0AA4`: sad seed beds dates saved cards darts scared trades stared 
- `F50E:0AE0`: as the ducks stood and stared, 
- `F50E:0B00`: the dogs sniffed the dish 
- `F50E:0B1B`: and tasted some of the seed.
- `F50E:0B38`: `<NUL terminator>`

### 28. `P-UI`

Cell: file `0x77E90`; label pointer `F50E:0B39`.

- `F50E:0B3E`: him hum oil hull ink union pupil lupin pumpkin 
- `F50E:0B6E`: five hiccupping pigs 
- `F50E:0B84`: and nine squinting squids 
- `F50E:0B9F`: quickly finished the fruit.
- `F50E:0BBB`: `<NUL terminator>`

### 29. `P-VB`

Cell: file `0x77ECC`; label pointer `F50E:0BBC`.

- `F50E:0BC1`: vat bet vase base save cave verb brave beaver verbal 
- `F50E:0BF7`: five brown bears 
- `F50E:0C09`: saved by 
- `F50E:0C13`: a very brave boy.
- `F50E:0C25`: `<NUL terminator>`

### 30. `P-WE`

Cell: file `0x77F08`; label pointer `F50E:0C26`.

- `F50E:0C2B`: wet few weave sweet stew were grew crew fewer reward 
- `F50E:0C61`: what weird whales.  
- `F50E:0C76`: ten were green, 
- `F50E:0C87`: a few were red.
- `F50E:0C97`: `<NUL terminator>`

### 31. `P-XC`

Cell: file `0x77F44`; label pointer `F50E:0C98`.

- `F50E:0C9D`: face fax cat tax ace exact extract excess exceed 
- `F50E:0CCF`: we fixed a box for the chicks, 
- `F50E:0CEF`: but the fox chose to chew the box.  
- `F50E:0D14`: now the fox has the chicks in a fix.
- `F50E:0D39`: `<NUL terminator>`

### 32. `P-YU`

Cell: file `0x77F80`; label pointer `F50E:0D3A`.

- `F50E:0D3F`: you my hum yummy puny jumpy puppy lumpy 
- `F50E:0D68`: your funny buddy 
- `F50E:0D7A`: is sure in a hurry 
- `F50E:0D8E`: to buy that rusty buoy.
- `F50E:0DA6`: `<NUL terminator>`

## Practice Guide Bank

### 01. `PG-A1`

Cell: file `0x77FF8`; label pointer `F50E:0DA8`.

- `F50E:0DAE`: I will call you again later when you are all there.
- `F50E:0DE2`: `<NUL terminator>`

### 02. `PG-A2`

Cell: file `0x78034`; label pointer `F50E:0DE3`.

- `F50E:0DE9`: It will be better if you all stay here for a while.
- `F50E:0E1D`: `<NUL terminator>`

### 03. `PG-A3`

Cell: file `0x78070`; label pointer `F50E:0E1E`.

- `F50E:0E24`: Let us see if we can make this move a bit faster.
- `F50E:0E56`: `<NUL terminator>`

### 04. `PG-B1`

Cell: file `0x780AC`; label pointer `F50E:0E57`.

- `F50E:0E5D`: They will soon want to have some idea of how to get there.
- `F50E:0E98`: `<NUL terminator>`

### 05. `PG-B2`

Cell: file `0x780E8`; label pointer `F50E:0E99`.

- `F50E:0E9F`: It will be good if you and he both can work on it this week.
- `F50E:0EDC`: `<NUL terminator>`

### 06. `PG-B3`

Cell: file `0x78124`; label pointer `F50E:0EDD`.

- `F50E:0EE3`: I hope to have some more details to offer you later today.
- `F50E:0F1E`: `<NUL terminator>`

### 07. `PG-C1`

Cell: file `0x78160`; label pointer `F50E:0F1F`.

- `F50E:0F25`: It may still be true that we will find even more of them than we 
- `F50E:0F67`: have seen to this point.
- `F50E:0F80`: `<NUL terminator>`

### 08. `PG-C2`

Cell: file `0x7819C`; label pointer `F50E:0F81`.

- `F50E:0F87`: You have shown that the cost will be lower, so we are now ready 
- `F50E:0FC8`: to go ahead as planned.
- `F50E:0FE0`: `<NUL terminator>`

### 09. `PG-C3`

Cell: file `0x781D8`; label pointer `F50E:0FE1`.

- `F50E:0FE7`: He would like to know if you can fill the order or if he should 
- `F50E:1028`: try to find another source.
- `F50E:1044`: `<NUL terminator>`

### 10. `PG-D1`

Cell: file `0x78214`; label pointer `F50E:1045`.

- `F50E:104B`: There is not much more we can do on this today as it will soon be 
- `F50E:108E`: time for us to go to meet the others.
- `F50E:10B4`: `<NUL terminator>`

### 11. `PG-D2`

Cell: file `0x78250`; label pointer `F50E:10B5`.

- `F50E:10BB`: You said that we should have given him more time to find what he 
- `F50E:10FD`: had lost, but you know that would have taken too long.
- `F50E:1134`: `<NUL terminator>`

### 12. `PG-D3`

Cell: file `0x7828C`; label pointer `F50E:1135`.

- `F50E:113B`: There is no need for us to wait to see if we still have their 
- `F50E:117A`: address as she has said that she will call him for us later today.
- `F50E:11BD`: `<NUL terminator>`

### 13. `PG-E1`

Cell: file `0x782C8`; label pointer `F50E:11BE`.

- `F50E:11C4`: We have submitted our report with respect to this matter.  The 
- `F50E:1204`: ideas we have set out will deal with the issues presented at our 
- `F50E:1246`: last planning meeting.
- `F50E:125D`: `<NUL terminator>`

### 14. `PG-E2`

Cell: file `0x78304`; label pointer `F50E:125E`.

- `F50E:1264`: Considering how little time it took them to complete the job, the 
- `F50E:12A7`: results were quite impressive.  They obviously had worked hard to 
- `F50E:12EA`: meet the deadline.
- `F50E:12FD`: `<NUL terminator>`

### 15. `PG-E3`

Cell: file `0x78340`; label pointer `F50E:12FE`.

- `F50E:1304`: We were concerned that they were not going to complete the work 
- `F50E:1345`: they had started.  We had not wanted it done so quickly, however, 
- `F50E:1388`: regardless of its perceived importance to this project.
- `F50E:13C0`: `<NUL terminator>`

### 16. `PG-F1`

Cell: file `0x7837C`; label pointer `F50E:13C1`.

- `F50E:13C7`: We regret that we have not yet been able to respond in writing to 
- `F50E:140A`: your stated position on the issues identified.  We would prefer 
- `F50E:144B`: to have an opportunity to study the written submission we have 
- `F50E:148B`: received rather than comment in writing now on the basis of 
- `F50E:14C8`: verbal presentations made last week.
- `F50E:14ED`: `<NUL terminator>`

### 17. `PG-F2`

Cell: file `0x783B8`; label pointer `F50E:14EE`.

- `F50E:14F4`: The major feature of the island is a ridge of high ground which is volcanic in 
- `F50E:1544`: origin.  There are many natural harbors along the indented coastline, but few 
- `F50E:1593`: rivers.  Rainfall is slight and the island has experienced severe drought.  
- `F50E:15E0`: The economic base has been primarily agricultural, but a tourist industry is 
- `F50E:162E`: now beginning to develop.
- `F50E:1648`: `<NUL terminator>`

### 18. `PG-F3`

Cell: file `0x783F4`; label pointer `F50E:1649`.

- `F50E:164F`: Norwegian boatbuilders uphold a proud and ancient tradition, 
- `F50E:168D`: fashioning wooden boats from the tall firs which grow in 
- `F50E:16C7`: abundance in the high mountains along the northern fjords.  As 
- `F50E:1707`: winter comes, farmers work together to convert their family barns 
- `F50E:174A`: into workshops, prepared to devote many cold, dark months to this 
- `F50E:178D`: profitable but demanding task.
- `F50E:17AC`: `<NUL terminator>`

### 19. `PG-G1`

Cell: file `0x78430`; label pointer `F50E:17AD`.

- `F50E:17B3`: It is generally agreed that the most popular section of this 
- `F50E:17F1`: great museum is situated on the first floor of the south wing, in 
- `F50E:1834`: a series of spacious rooms overlooking the courtyard and 
- `F50E:186E`: approached by another of those elegant staircases which 
- `F50E:18A7`: distinguish the palace.  Here there is rich and extensive 
- `F50E:18E2`: documentation of the life and customs of inhabitants of the 
- `F50E:191F`: fertile triangle of the old world, illustrated by all manner of 
- `F50E:1960`: everyday objects, furniture, games, musical instruments and 
- `F50E:199D`: tools.  The highlight for most visitors, however, is undoubtedly 
- `F50E:19DF`: the matchless collection of fine masterpieces which must 
- `F50E:1A19`: represent the pinnacle of the artistic creation of these cultures.
- `F50E:1A5C`: `<NUL terminator>`

### 20. `PG-G2`

Cell: file `0x7846C`; label pointer `F50E:1A5D`.

- `F50E:1A63`: We had vivid memories of those sunny days.  We remembered 
- `F50E:1A9E`: swimming in the river and wading in the creek which fed it.  
- `F50E:1ADC`: Together we would catch leeches, tadpoles, newts, frogs and 
- `F50E:1B19`: yabbies.  Those were the days of endless picnics in the country 
- `F50E:1B5A`: meadows, followed by an eager hunt for the elusive seasonal 
- `F50E:1B97`: mushroom, a rare item which would lure even the city and the 
- `F50E:1BD5`: beach people to the bush.  There were horses, and we rode 
- `F50E:1C10`: frequently to the foothills where there was an apiary owned by a 
- `F50E:1C52`: number of brothers who shared with us the honey from the bees.  
- `F50E:1C93`: Up the hillside there were wheatfields and grazing sheep which 
- `F50E:1CD3`: belonged, we were told, to the descendents of one of the very 
- `F50E:1D12`: first settlers.
- `F50E:1D22`: `<NUL terminator>`

### 21. `PG-G3`

Cell: file `0x784A8`; label pointer `F50E:1D23`.

- `F50E:1D29`: An exotic bird, the toucan is graced with an enormous hooked beak, often as 
- `F50E:1D76`: big as its whole body.  Surprisingly, this smooth, sharp and highly colored 
- `F50E:1DC3`: appendage appears to serve no adaptive function.  The toucan is found wild 
- `F50E:1E0F`: only in the tropical forests of the western hemisphere, living mainly on fruit 
- `F50E:1E5F`: and berries, feeding occasionally on large insects, but the toucan never seeks 
- `F50E:1EAF`: out the more resilient foodstuffs which might justify such a massive bill.  
- `F50E:1EFC`: Nor does the beak provide effective protection from the toucan's principal 
- `F50E:1F48`: predators, the hawks and weasels, and if it serves as a recognition mark 
- `F50E:1F92`: between members of the same species or plays some part in courtship display, 
- `F50E:1FE0`: this has not been observed or recorded.  We can only conclude that it is just 
- `F50E:202F`: a fortuitous development or another odd quirk of nature.
- `F50E:2068`: `<NUL terminator>`

### 22. `PGACC-BV`

Cell: file `0x784E4`; label pointer `F50E:2069`.

- `F50E:2072`: bevy verb above vibes brave viable beaver 
- `F50E:209D`: verbal behave visible bovine vibrato bivouac 
- `F50E:20CB`: vibrant beloved valuable believe verbatim bevelled
- `F50E:20FE`: `<NUL terminator>`

### 23. `PGACC-CV`

Cell: file `0x78520`; label pointer `F50E:20FF`.

- `F50E:2108`: cove voice chive vocal clove vicar cave 
- `F50E:2131`: voice cover vacant crave advice civil device clever 
- `F50E:2166`: victor cravat novice cleave voucher cavern service
- `F50E:2199`: `<NUL terminator>`

### 24. `PGACC-CX`

Cell: file `0x7855C`; label pointer `F50E:219A`.

- `F50E:21A3`: cox exact coax excel crux toxic convex 
- `F50E:21CB`: excite cortex excise coccyx boxcar commix 
- `F50E:21F6`: excuses context extract complex execute coaxial
- `F50E:2226`: `<NUL terminator>`

### 25. `PGACC-IO`

Cell: file `0x78598`; label pointer `F50E:2227`.

- `F50E:2230`: ion oil into join idol boil iron omit axiom 
- `F50E:225D`: doing igloo logic iodine onion inform commit 
- `F50E:228B`: ignore mobile intone obtain innovate choice impose
- `F50E:22BE`: `<NUL terminator>`

### 26. `PGACC-MN`

Cell: file `0x785D4`; label pointer `F50E:22BF`.

- `F50E:22C8`: men name mane numb mean norm main gnome 
- `F50E:22F1`: amend enemy money denim human normal manage 
- `F50E:231E`: nutmeg amount inmate common nimble salmon animal
- `F50E:234F`: `<NUL terminator>`

### 27. `PGACC-RE`

Cell: file `0x78610`; label pointer `F50E:2350`.

- `F50E:2359`: red ear are per read deer care fear reef early 
- `F50E:2389`: rouse error rodeo erode ruler merry forest euchre 
- `F50E:23BC`: frieze clever praise letter forget memories remember
- `F50E:23F1`: `<NUL terminator>`

### 28. `PGACC-RT`

Cell: file `0x7864C`; label pointer `F50E:23F2`.

- `F50E:23FB`: rat tar rot torn rent turn rate tire rote tear 
- `F50E:242B`: roast stare wrath third write taper route trout 
- `F50E:245C`: rather turret regret target credit sister return
- `F50E:248D`: `<NUL terminator>`

### 29. `PGACC-SD`

Cell: file `0x78688`; label pointer `F50E:248E`.

- `F50E:2497`: sad days adds sand dash acids said dads asked 
- `F50E:24C6`: shade dates aside saved daisy adults salted 
- `F50E:24F3`: drapes advise stated danish masked seated
- `F50E:251D`: `<NUL terminator>`

### 30. `PGACC-UI`

Cell: file `0x786C4`; label pointer `F50E:251E`.

- `F50E:2527`: suit imbue quit issue quid pique quail incur 
- `F50E:2555`: until atrium fruit pious quiet helium druid 
- `F50E:2582`: odious futile tissue duties injury juries include
- `F50E:25B4`: `<NUL terminator>`

### 31. `PGACC-WE`

Cell: file `0x78700`; label pointer `F50E:25B5`.

- `F50E:25BE`: awe ewe woe sew wet view wire news when grew 
- `F50E:25EC`: woven fewer water below wierd elbow mower newly 
- `F50E:261D`: women enwrap lawyer shrewd writer mellow wonder
- `F50E:264D`: `<NUL terminator>`

### 32. `PGACC-YU`

Cell: file `0x7873C`; label pointer `F50E:264E`.

- `F50E:2657`: you guy yak duty your fury yule ugly youth 
- `F50E:2683`: unify young unity yucca husky yogurt injury 
- `F50E:26B0`: eyeful unruly gypsum hourly yuppies untidy stylus
- `F50E:26E2`: `<NUL terminator>`

### 33. `PGPUNCT`

Cell: file `0x78778`; label pointer `F50E:26E3`.

- `F50E:26EB`: do, re, mi, fa, sol, la, ti, do, 
- `F50E:270D`: do.  re.  mi.  fa.  sol.  la.  ti.  do.  
- `F50E:2737`: do, re.  mi, fa.  sol, la.  ti, do.
- `F50E:275B`: `<NUL terminator>`
