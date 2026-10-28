// <emoji-picker> — the standard emoji picker: a search box that narrows
// a few hundred emoji by name or keyword, category tabs, a "recent" row
// remembered per browser, and a Custom tab for any string at all (an
// emoji not listed, a :shortcode:, a word). Self-contained: the data
// is in this file, nothing is fetched.
//
// USAGE
//   <emoji-picker id="ep"></emoji-picker>
//   ep.addEventListener('ep-pick', e => react(e.detail.emoji));
//   ep.open(); ep.close(); ep.toggle();        // or the `open` attribute
//   ep.focus()                                  // puts the caret in the search box
//   Anything typed can be sent as-is (the "use … as-is" row / Enter with no hits).
//
// CONTRACT
//   attributes (config in):
//     open      boolean; visible (popover use)
//     inline    boolean; not a popover: always shown, static position, no
//               outside-click close — for putting it inside a modal
//     persist   localStorage key for the recent row (default "emoji-recent")
//     columns   grid columns (default 8)
//   css vars (theme in), house-light defaults:
//     --ep-bg, --ep-border, --ep-accent (default #6b3fd6), --ep-width (default 300px)
//   events (state out), bubbling + composed:
//     ep-pick   { emoji, name }   — after a choice; the picker closes itself
//     ep-close                    — closed (Esc, outside click, or a pick)
//
// DESIGN NOTES — position is the host's: the picker is `position: absolute`
// and the host places it (a relative wrapper). Keep the template
// backtick-free. The data line format is "emoji name keyword keyword…",
// one per line, grouped by category headers "# Category".

const DATA = `
# Smileys
😀 grinning smile happy
😃 smiley happy joy
😄 smile happy laugh
😁 grin beam
😆 laughing squint haha
😅 sweat smile relief
🤣 rofl rolling laughing
😂 joy tears laugh lol
🙂 slight smile
🙃 upside down
😉 wink
😊 blush smile
😇 innocent angel halo
🥰 hearts love smiling
😍 heart eyes love
🤩 star struck wow
😘 kiss blow
😗 kissing
😚 kissing closed eyes
😙 kissing smiling
🥲 smiling tear
😋 yum delicious tongue
😛 tongue
😜 wink tongue crazy
🤪 zany crazy
😝 squint tongue
🤑 money mouth rich
🤗 hug hugging
🤭 hand over mouth giggle
🤫 shush quiet secret
🤔 thinking hmm
🫡 salute
🤐 zipper mouth
🤨 raised eyebrow skeptic
😐 neutral meh
😑 expressionless
😶 no mouth silent
🫥 dotted line invisible
😏 smirk
😒 unamused
🙄 eye roll
😬 grimace awkward
🤥 lying pinocchio
😌 relieved
😔 pensive sad
😪 sleepy
🤤 drooling
😴 sleeping zzz
😷 mask sick
🤒 thermometer sick fever
🤕 bandage hurt
🤢 nauseated sick
🤮 vomit
🤧 sneeze tissue
🥵 hot sweating
🥶 cold freezing
🥴 woozy drunk
😵 dizzy dead
😵‍💫 spiral dizzy
🤯 exploding head mind blown
🤠 cowboy
🥳 party celebrate
🥸 disguise
😎 sunglasses cool
🤓 nerd glasses
🧐 monocle
😕 confused
🫤 diagonal mouth
😟 worried
🙁 frown sad
☹️ frowning sad
😮 open mouth surprised
😯 hushed
😲 astonished shocked
😳 flushed embarrassed
🥺 pleading puppy eyes
🥹 holding back tears
😦 frowning open mouth
😧 anguished
😨 fearful scared
😰 anxious sweat
😥 sad relieved
😢 cry tear sad
😭 sob crying loud
😱 scream fear
😖 confounded
😣 persevering
😞 disappointed
😓 downcast sweat
😩 weary tired
😫 tired
🥱 yawn bored
😤 triumph huff steam
😡 pouting angry rage
😠 angry mad
🤬 cursing swearing
😈 smiling devil
👿 angry devil imp
💀 skull dead
☠️ skull crossbones
💩 poop
🤡 clown
👹 ogre
👺 goblin
👻 ghost
👽 alien
👾 space invader
🤖 robot
😺 cat smile
😸 cat grin
😹 cat joy
😻 cat heart eyes
😼 cat smirk
😽 cat kiss
🙀 cat scream
😿 cat cry
😾 cat pouting
🙈 see no evil monkey
🙉 hear no evil monkey
🙊 speak no evil monkey
# Gestures & people
👋 wave hello bye
🤚 raised back hand
🖐️ hand fingers splayed
✋ raised hand stop
🖖 vulcan spock
🫱 rightwards hand
🫲 leftwards hand
🫶 heart hands
👌 ok
🤌 pinched fingers italian
🤏 pinching small
✌️ victory peace
🤞 crossed fingers luck
🫰 hand heart finger
🤟 love you
🤘 rock horns metal
🤙 call me shaka
👈 point left
👉 point right
👆 point up
🖕 middle finger
👇 point down
☝️ index up
👍 thumbs up like yes
👎 thumbs down dislike no
✊ fist
👊 punch fist bump
🤛 left fist
🤜 right fist
👏 clap applause
🙌 raised hands hooray
🫸 pushing hand right
🫷 pushing hand left
👐 open hands
🤲 palms up
🤝 handshake deal
🙏 pray please thanks
✍️ writing
💅 nail polish
🤳 selfie
💪 muscle strong flex
🦾 mechanical arm
🦵 leg
🦶 foot
👂 ear
👃 nose
🧠 brain
🫀 heart organ
🫁 lungs
🦷 tooth
🦴 bone
👀 eyes look
👁️ eye
👅 tongue
👄 mouth lips
🫦 biting lip
👶 baby
🧒 child
👦 boy
👧 girl
🧑 person adult
👱 blond
👨 man
🧔 beard
👩 woman
🧓 older person
👴 old man
👵 old woman
🙍 frowning person
🙎 pouting person
🙅 no gesture
🙆 ok gesture
💁 tipping hand
🙋 raising hand
🧏 deaf
🙇 bow
🤦 facepalm
🤷 shrug
👮 police
🕵️ detective
💂 guard
🥷 ninja
👷 construction worker
🤴 prince
👸 princess
👳 turban
👲 gua pi mao
🧕 headscarf
🤵 tuxedo
👰 veil bride
🤰 pregnant
🤱 breast feeding
👼 baby angel
🎅 santa
🤶 mrs claus
🦸 superhero
🦹 supervillain
🧙 mage wizard
🧚 fairy
🧛 vampire
🧜 merperson
🧝 elf
🧞 genie
🧟 zombie
💆 massage
💇 haircut
🚶 walking
🏃 running
💃 dancer
🕺 man dancing
👯 bunny ears
🧘 lotus meditation
🛀 bath
🛌 bed sleeping
👭 women holding hands
👫 couple holding hands
👬 men holding hands
💏 kiss couple
💑 couple heart
👪 family
🗣️ speaking head
👤 silhouette
👥 busts people
🫂 hug people hugging
👣 footprints
# Animals & nature
🐶 dog puppy
🐱 cat kitten
🐭 mouse
🐹 hamster
🐰 rabbit bunny
🦊 fox
🐻 bear
🐼 panda
🐻‍❄️ polar bear
🐨 koala
🐯 tiger
🦁 lion
🐮 cow
🐷 pig
🐸 frog
🐵 monkey
🐔 chicken
🐧 penguin
🐦 bird
🐤 chick
🦆 duck
🦅 eagle
🦉 owl
🦇 bat
🐺 wolf
🐗 boar
🐴 horse
🦄 unicorn
🐝 bee
🪲 beetle
🐛 bug caterpillar
🦋 butterfly
🐌 snail
🐞 ladybug
🐜 ant
🦟 mosquito
🐢 turtle
🐍 snake
🦎 lizard
🦖 t-rex dinosaur
🦕 sauropod dinosaur
🐙 octopus
🦑 squid
🦐 shrimp
🦀 crab
🐡 blowfish
🐠 tropical fish
🐟 fish
🐬 dolphin
🐳 whale
🦈 shark
🐊 crocodile
🐅 tiger
🐆 leopard
🦓 zebra
🦍 gorilla
🦧 orangutan
🐘 elephant
🦛 hippo
🦏 rhino
🐪 camel
🦒 giraffe
🦘 kangaroo
🐃 water buffalo
🐂 ox
🐄 cow
🐎 horse racing
🐖 pig
🐏 ram
🐑 sheep
🐐 goat
🦌 deer
🐕 dog
🐩 poodle
🐈 cat
🐓 rooster
🦃 turkey
🦚 peacock
🦜 parrot
🦢 swan
🦩 flamingo
🕊️ dove peace
🐇 rabbit
🦝 raccoon
🦨 skunk
🦡 badger
🦫 beaver
🦦 otter
🦥 sloth
🐁 mouse
🐀 rat
🐿️ chipmunk squirrel
🦔 hedgehog
🐾 paw prints
🐉 dragon
🐲 dragon face
🌵 cactus
🎄 christmas tree
🌲 evergreen tree
🌳 tree
🌴 palm tree
🪵 wood log
🌱 seedling sprout
🌿 herb
☘️ shamrock
🍀 four leaf clover luck
🎍 bamboo
🪴 potted plant
🎋 tanabata tree
🍃 leaves wind
🍂 fallen leaves autumn
🍁 maple leaf
🍄 mushroom
🐚 shell
🪨 rock stone
🌾 rice ear
💐 bouquet
🌷 tulip
🌹 rose
🥀 wilted flower
🌺 hibiscus
🌸 cherry blossom
🌼 blossom
🌻 sunflower
🌞 sun face
🌝 full moon face
🌛 first quarter moon face
🌜 last quarter moon face
🌚 new moon face
🌕 full moon
🌙 crescent moon
🌎 earth americas globe
🌍 earth europe africa globe
🌏 earth asia globe
🪐 planet saturn
💫 dizzy star
⭐ star
🌟 glowing star
✨ sparkles
⚡ lightning zap bolt
☄️ comet
💥 boom explosion collision
🔥 fire lit hot
🌪️ tornado
🌈 rainbow
☀️ sun sunny
🌤️ sun small cloud
⛅ sun behind cloud
🌥️ sun large cloud
☁️ cloud
🌦️ rain sun
🌧️ rain cloud
⛈️ thunder lightning cloud
🌩️ lightning cloud
🌨️ snow cloud
❄️ snowflake cold
☃️ snowman
⛄ snowman
🌬️ wind face
💨 dash wind fast
💧 droplet water
💦 sweat droplets splash
☔ umbrella rain
🌊 wave ocean water
🌫️ fog
# Food & drink
🍏 green apple
🍎 apple
🍐 pear
🍊 tangerine orange
🍋 lemon
🍌 banana
🍉 watermelon
🍇 grapes
🍓 strawberry
🫐 blueberries
🍈 melon
🍒 cherries
🍑 peach
🥭 mango
🍍 pineapple
🥥 coconut
🥝 kiwi
🍅 tomato
🍆 eggplant
🥑 avocado
🥦 broccoli
🥬 leafy green
🥒 cucumber
🌶️ hot pepper spicy
🫑 bell pepper
🌽 corn
🥕 carrot
🫒 olive
🧄 garlic
🧅 onion
🥔 potato
🍠 sweet potato
🥐 croissant
🥯 bagel
🍞 bread
🥖 baguette
🥨 pretzel
🧀 cheese
🥚 egg
🍳 fried egg cooking
🧈 butter
🥞 pancakes
🧇 waffle
🥓 bacon
🥩 steak meat
🍗 poultry leg chicken
🍖 meat bone
🌭 hot dog
🍔 burger hamburger
🍟 fries
🍕 pizza
🫓 flatbread
🥪 sandwich
🥙 stuffed flatbread
🧆 falafel
🌮 taco
🌯 burrito
🫔 tamale
🥗 salad
🥘 paella
🫕 fondue
🍝 spaghetti pasta
🍜 ramen noodles
🍲 stew
🍛 curry
🍣 sushi
🍱 bento
🥟 dumpling
🦪 oyster
🍤 shrimp fried
🍙 rice ball
🍚 rice
🍘 rice cracker
🍥 fish cake
🥠 fortune cookie
🥮 moon cake
🍢 oden
🍡 dango
🍧 shaved ice
🍨 ice cream
🍦 soft ice cream
🥧 pie
🧁 cupcake
🍰 cake shortcake
🎂 birthday cake
🍮 custard pudding
🍭 lollipop
🍬 candy
🍫 chocolate
🍿 popcorn
🍩 doughnut donut
🍪 cookie
🌰 chestnut
🥜 peanuts
🍯 honey
🥛 milk
🍼 baby bottle
🫖 teapot
☕ coffee hot
🍵 tea
🧃 juice box
🥤 cup straw soda
🧋 bubble tea boba
🍶 sake
🍺 beer
🍻 beers cheers
🥂 clinking glasses champagne cheers
🍷 wine
🥃 whisky tumbler
🍸 cocktail martini
🍹 tropical drink
🧉 mate
🍾 champagne bottle pop
🧊 ice cube
🥄 spoon
🍴 fork knife
🍽️ plate cutlery
🥣 bowl spoon
🥡 takeout box
🧂 salt
# Activities
⚽ soccer football
🏀 basketball
🏈 american football
⚾ baseball
🥎 softball
🎾 tennis
🏐 volleyball
🏉 rugby
🥏 frisbee
🎱 8 ball pool billiards
🪀 yo-yo
🏓 ping pong table tennis
🏸 badminton
🏒 hockey
🥍 lacrosse
🏏 cricket
🪃 boomerang
🥅 goal net
⛳ golf flag
🪁 kite
🏹 bow arrow archery
🎣 fishing
🤿 diving mask
🥊 boxing glove
🥋 martial arts
🎽 running shirt
🛹 skateboard
🛼 roller skate
🛷 sled
⛸️ ice skate
🥌 curling stone
🎿 ski
⛷️ skier
🏂 snowboarder
🏋️ weight lifting gym
🤼 wrestling
🤸 cartwheel gymnastics
⛹️ bouncing ball
🤺 fencing
🤾 handball
🏌️ golfing
🏇 horse racing
🧘 yoga meditate
🏄 surfing
🏊 swimming
🤽 water polo
🚣 rowing
🧗 climbing
🚴 cycling bike
🚵 mountain biking
🏆 trophy winner
🥇 gold medal first
🥈 silver medal second
🥉 bronze medal third
🏅 medal
🎖️ military medal
🏵️ rosette
🎗️ reminder ribbon
🎫 ticket
🎟️ admission tickets
🎪 circus tent
🤹 juggling
🎭 performing arts theatre
🩰 ballet shoes
🎨 art palette paint
🎬 clapper board movie
🎤 microphone sing
🎧 headphones music
🎼 musical score
🎹 piano keyboard
🥁 drum
🪘 long drum
🎷 saxophone
🎺 trumpet
🪗 accordion
🎸 guitar
🪕 banjo
🎻 violin
🎲 dice game
♟️ chess pawn
🎯 bullseye target dart
🎳 bowling
🎮 video game controller
🕹️ joystick
🎰 slot machine
🧩 puzzle piece
# Travel & places
🚗 car
🚕 taxi
🚙 suv
🛻 pickup truck
🚌 bus
🚎 trolleybus
🏎️ racing car
🚓 police car
🚑 ambulance
🚒 fire engine
🚐 minibus
🚚 delivery truck
🚛 articulated lorry
🚜 tractor
🦯 white cane
🦽 wheelchair
🛴 kick scooter
🚲 bicycle bike
🛵 motor scooter
🏍️ motorcycle
🛺 auto rickshaw
🚨 police light siren
🚔 oncoming police car
🚍 oncoming bus
🚘 oncoming car
🚖 oncoming taxi
🚡 aerial tramway
🚠 mountain cableway
🚟 suspension railway
🚃 railway car
🚋 tram car
🚞 mountain railway
🚝 monorail
🚄 high speed train
🚅 bullet train
🚈 light rail
🚂 locomotive train
🚆 train
🚇 metro subway
🚊 tram
🚉 station
✈️ airplane flight
🛫 departure takeoff
🛬 arrival landing
🛩️ small airplane
💺 seat
🛰️ satellite
🚀 rocket launch
🛸 flying saucer ufo
🚁 helicopter
🛶 canoe
⛵ sailboat
🚤 speedboat
🛥️ motor boat
🛳️ passenger ship
⛴️ ferry
🚢 ship
⚓ anchor
🪝 hook
⛽ fuel pump gas
🚧 construction
🚦 traffic light
🚥 horizontal traffic light
🛑 stop sign
🚏 bus stop
🗺️ world map
🗿 moai statue
🗽 statue of liberty
🗼 tokyo tower
🏰 castle
🏯 japanese castle
🏟️ stadium
🎡 ferris wheel
🎢 roller coaster
🎠 carousel
⛲ fountain
⛱️ umbrella beach
🏖️ beach
🏝️ desert island
🏜️ desert
🌋 volcano
⛰️ mountain
🏔️ snow mountain
🗻 mount fuji
🏕️ camping tent
⛺ tent
🛖 hut
🏠 house home
🏡 house garden
🏘️ houses
🏚️ derelict house
🏗️ construction crane
🏭 factory
🏢 office building
🏬 department store
🏣 japanese post office
🏤 post office
🏥 hospital
🏦 bank
🏨 hotel
🏪 convenience store
🏫 school
🏩 love hotel
💒 wedding
🏛️ classical building
⛪ church
🕌 mosque
🛕 hindu temple
🕍 synagogue
🕋 kaaba
⛩️ shinto shrine
🛤️ railway track
🛣️ motorway highway
🗾 japan map
🎑 moon viewing
🏞️ national park
🌅 sunrise
🌄 sunrise mountains
🌠 shooting star
🎇 sparkler
🎆 fireworks
🌇 sunset
🌆 cityscape dusk
🏙️ cityscape
🌃 night stars
🌌 milky way galaxy
🌉 bridge night
🌁 foggy
# Objects
⌚ watch
📱 phone mobile
📲 phone arrow
💻 laptop computer
⌨️ keyboard
🖥️ desktop computer
🖨️ printer
🖱️ mouse computer
🖲️ trackball
🕹️ joystick
🗜️ clamp
💽 minidisc
💾 floppy disk save
💿 cd disc
📀 dvd
📼 vhs videocassette
📷 camera photo
📸 camera flash
📹 video camera
🎥 movie camera film
📽️ film projector
🎞️ film frames
📞 telephone receiver
☎️ telephone
📟 pager
📠 fax
📺 tv television
📻 radio
🎙️ studio microphone
🎚️ level slider
🎛️ control knobs
🧭 compass
⏱️ stopwatch
⏲️ timer
⏰ alarm clock
🕰️ mantelpiece clock
⌛ hourglass done
⏳ hourglass
📡 satellite antenna
🔋 battery
🪫 low battery
🔌 plug
💡 light bulb idea
🔦 flashlight
🕯️ candle
🪔 diya lamp
🧯 fire extinguisher
🛢️ oil drum
💸 money wings
💵 dollar
💴 yen
💶 euro
💷 pound
🪙 coin
💰 money bag
💳 credit card
💎 gem diamond
⚖️ balance scale justice
🪜 ladder
🧰 toolbox
🪛 screwdriver
🔧 wrench
🔨 hammer
⚒️ hammer pick
🛠️ hammer wrench tools
⛏️ pick
🪚 saw
🔩 nut bolt
⚙️ gear settings
🪤 mouse trap
🧱 brick
⛓️ chains
🧲 magnet
🔫 water pistol
💣 bomb
🧨 firecracker
🪓 axe
🔪 knife
🗡️ dagger
⚔️ crossed swords
🛡️ shield
🚬 cigarette
⚰️ coffin
🪦 headstone
⚱️ urn
🏺 amphora
🔮 crystal ball
📿 prayer beads
🧿 nazar amulet
🪬 hamsa
💈 barber pole
⚗️ alembic
🔭 telescope
🔬 microscope
🕳️ hole
🩹 bandage
🩺 stethoscope
💊 pill
💉 syringe
🩸 blood drop
🧬 dna
🦠 microbe virus
🧫 petri dish
🧪 test tube
🌡️ thermometer
🧹 broom
🪠 plunger
🧺 basket
🧻 toilet paper
🚽 toilet
🚰 potable water
🚿 shower
🛁 bathtub
🛀 bath
🧼 soap
🪥 toothbrush
🪒 razor
🧽 sponge
🪣 bucket
🧴 lotion
🛎️ bellhop bell
🔑 key
🗝️ old key
🚪 door
🪑 chair
🛋️ couch
🛏️ bed
🧸 teddy bear
🪆 nesting dolls
🖼️ framed picture
🪞 mirror
🪟 window
🛍️ shopping bags
🛒 shopping cart
🎁 gift present
🎈 balloon
🎏 carp streamer
🎀 ribbon
🪄 magic wand
🪅 piñata
🎊 confetti
🎉 party popper tada celebrate
🎎 japanese dolls
🏮 lantern
🎐 wind chime
🧧 red envelope
✉️ envelope email
📩 envelope arrow
📨 incoming envelope
📧 email
💌 love letter
📥 inbox
📤 outbox
📦 package box
🏷️ label tag
🪧 placard
📪 mailbox closed
📫 mailbox
📬 mailbox mail
📭 mailbox empty
📮 postbox
📯 postal horn
📜 scroll
📃 page curl
📄 page document
📑 bookmark tabs
🧾 receipt
📊 bar chart
📈 chart up increasing
📉 chart down decreasing
🗒️ notepad
🗓️ calendar spiral
📆 calendar tear off
📅 calendar date
🗑️ wastebasket trash
📇 card index
🗃️ card file box
🗳️ ballot box vote
🗄️ file cabinet
📋 clipboard
📁 folder
📂 open folder
🗂️ dividers
🗞️ newspaper rolled
📰 newspaper news
📓 notebook
📔 notebook decorative
📒 ledger
📕 red book
📗 green book
📘 blue book
📙 orange book
📚 books
📖 open book reading
🔖 bookmark
🧷 safety pin
🔗 link chain
📎 paperclip
🖇️ paperclips
📐 triangular ruler
📏 ruler
🧮 abacus
📌 pushpin pin
📍 round pushpin location
✂️ scissors
🖊️ pen
🖋️ fountain pen
✒️ black nib
🖌️ paintbrush
🖍️ crayon
📝 memo note pencil
✏️ pencil
🔍 magnifier search left
🔎 magnifier search right
🔏 locked pen
🔐 locked key
🔒 locked lock
🔓 unlocked
# Symbols
❤️ red heart love
🧡 orange heart
💛 yellow heart
💚 green heart
💙 blue heart
💜 purple heart
🖤 black heart
🤍 white heart
🤎 brown heart
🩷 pink heart
🩵 light blue heart
🩶 grey heart
💔 broken heart
❤️‍🔥 heart on fire
❤️‍🩹 mending heart
❣️ heart exclamation
💕 two hearts
💞 revolving hearts
💓 beating heart
💗 growing heart
💖 sparkling heart
💘 heart arrow cupid
💝 heart ribbon gift
💟 heart decoration
☮️ peace
✝️ cross
☪️ star crescent
🕉️ om
☸️ dharma wheel
✡️ star of david
🔯 six pointed star
🕎 menorah
☯️ yin yang
☦️ orthodox cross
🛐 place of worship
⛎ ophiuchus
♈ aries
♉ taurus
♊ gemini
♋ cancer
♌ leo
♍ virgo
♎ libra
♏ scorpio
♐ sagittarius
♑ capricorn
♒ aquarius
♓ pisces
🆔 id
⚛️ atom science
🉑 accept
☢️ radioactive
☣️ biohazard
📴 mobile off
📳 vibration mode
🈶 not free of charge
🈚 free of charge
🈸 application
🈺 open for business
🈷️ monthly amount
✴️ eight pointed star
🆚 vs versus
💮 white flower
🉐 bargain
㊙️ secret
㊗️ congratulations
🈴 passing grade
🈵 no vacancy
🈹 discount
🈲 prohibited
🅰️ a blood type
🅱️ b blood type
🆎 ab
🆑 cl
🅾️ o blood type
🆘 sos help
❌ cross mark x no wrong
⭕ hollow red circle
🛑 stop
⛔ no entry
📛 name badge
🚫 prohibited forbidden
💯 hundred 100 perfect
💢 anger
♨️ hot springs
🚷 no pedestrians
🚯 no littering
🚳 no bicycles
🚱 non potable water
🔞 18 adults only
📵 no mobile phones
🚭 no smoking
❗ exclamation
❕ white exclamation
❓ question
❔ white question
‼️ double exclamation
⁉️ exclamation question
🔅 dim
🔆 bright
〽️ part alternation
⚠️ warning caution
🚸 children crossing
🔱 trident
⚜️ fleur de lis
🔰 beginner
♻️ recycle
✅ check mark button yes done
🈯 reserved
💹 chart yen
❇️ sparkle
✳️ eight spoked asterisk
❎ cross mark button
🌐 globe meridians web
💠 diamond dot
Ⓜ️ circled m
🌀 cyclone
💤 zzz sleep
🏧 atm
🚾 wc
♿ wheelchair
🅿️ parking
🛗 elevator
🈳 vacancy
🈂️ service charge
🛂 passport control
🛃 customs
🛄 baggage claim
🛅 left luggage
🚹 mens
🚺 womens
🚼 baby symbol
⚧️ transgender
🚻 restroom
🚮 litter bin
🎦 cinema
📶 signal bars
🈁 here
🔣 symbols
ℹ️ information
🔤 abc letters
🔡 abcd lowercase
🔠 abcd uppercase
🆖 ng
🆗 ok button
🆙 up
🆒 cool
🆕 new
🆓 free
0️⃣ zero
1️⃣ one
2️⃣ two
3️⃣ three
4️⃣ four
5️⃣ five
6️⃣ six
7️⃣ seven
8️⃣ eight
9️⃣ nine
🔟 ten
🔢 numbers 1234
#️⃣ hash
*️⃣ asterisk
⏏️ eject
▶️ play
⏸️ pause
⏯️ play pause
⏹️ stop
⏺️ record
⏭️ next track
⏮️ previous track
⏩ fast forward
⏪ rewind
⏫ fast up
⏬ fast down
◀️ reverse
🔼 up button
🔽 down button
➡️ right arrow
⬅️ left arrow
⬆️ up arrow
⬇️ down arrow
↗️ up right arrow
↘️ down right arrow
↙️ down left arrow
↖️ up left arrow
↕️ up down arrow
↔️ left right arrow
↪️ right hook arrow
↩️ left hook arrow
⤴️ arrow curving up
⤵️ arrow curving down
🔀 shuffle
🔁 repeat
🔂 repeat one
🔄 arrows counterclockwise refresh
🔃 arrows clockwise
🎵 musical note
🎶 musical notes
➕ plus
➖ minus
➗ divide
✖️ multiply
🟰 equals
♾️ infinity
💲 dollar sign
💱 currency exchange
™️ trademark
©️ copyright
®️ registered
👁️‍🗨️ eye speech bubble
🔚 end
🔙 back
🔛 on
🔝 top
🔜 soon
〰️ wavy dash
➰ curly loop
➿ double curly loop
✔️ check mark
☑️ check box
🔘 radio button
🔴 red circle
🟠 orange circle
🟡 yellow circle
🟢 green circle
🔵 blue circle
🟣 purple circle
⚫ black circle
⚪ white circle
🟤 brown circle
🔺 red triangle up
🔻 red triangle down
🔸 small orange diamond
🔹 small blue diamond
🔶 large orange diamond
🔷 large blue diamond
🔳 white square button
🔲 black square button
▪️ black small square
▫️ white small square
◾ black medium small square
◽ white medium small square
◼️ black medium square
◻️ white medium square
🟥 red square
🟧 orange square
🟨 yellow square
🟩 green square
🟦 blue square
🟪 purple square
⬛ black square
⬜ white square
🟫 brown square
🔈 speaker low
🔇 muted speaker
🔉 speaker medium
🔊 speaker loud
🔔 bell notification
🔕 bell slash
📣 megaphone
📢 loudspeaker
💬 speech balloon comment
💭 thought balloon
🗯️ anger bubble
♠️ spade suit
♣️ club suit
♥️ heart suit
♦️ diamond suit
🃏 joker
🎴 flower playing cards
🀄 mahjong
🕐 one oclock
🕑 two oclock
🕒 three oclock
🕓 four oclock
🕔 five oclock
🕕 six oclock
🕖 seven oclock
🕗 eight oclock
🕘 nine oclock
🕙 ten oclock
🕚 eleven oclock
🕛 twelve oclock
# Flags
🏁 chequered flag finish
🚩 triangular flag red
🎌 crossed flags
🏴 black flag
🏳️ white flag
🏳️‍🌈 rainbow flag pride
🏳️‍⚧️ transgender flag
🏴‍☠️ pirate flag
🇺🇳 united nations
🇺🇸 usa united states america
🇬🇧 uk united kingdom britain
🇨🇦 canada
🇫🇷 france
🇩🇪 germany
🇪🇸 spain
🇮🇹 italy
🇵🇹 portugal
🇳🇱 netherlands
🇧🇪 belgium
🇨🇭 switzerland
🇦🇹 austria
🇸🇪 sweden
🇳🇴 norway
🇩🇰 denmark
🇫🇮 finland
🇮🇪 ireland
🇵🇱 poland
🇨🇿 czechia
🇬🇷 greece
🇹🇷 turkey
🇺🇦 ukraine
🇷🇺 russia
🇯🇵 japan
🇰🇷 korea
🇨🇳 china
🇮🇳 india
🇧🇷 brazil
🇲🇽 mexico
🇦🇷 argentina
🇨🇴 colombia
🇨🇱 chile
🇦🇺 australia
🇳🇿 new zealand
🇿🇦 south africa
🇳🇬 nigeria
🇪🇬 egypt
🇰🇪 kenya
🇮🇱 israel
🇸🇦 saudi arabia
🇦🇪 uae emirates
🇮🇩 indonesia
🇵🇭 philippines
🇻🇳 vietnam
🇹🇭 thailand
🇸🇬 singapore
🇲🇾 malaysia
🇵🇰 pakistan
🇮🇷 iran
🇮🇸 iceland
🇪🇺 european union eu
`;

// parse once: [{ e, name, kw, cat }]
const CATS = [];
const ALL = [];
DATA.split('\n').forEach((line) => {
  line = line.trim(); if (!line) return;
  if (line.charAt(0) === '#' && line.charAt(1) === ' ') { CATS.push(line.slice(2)); return; }
  const sp = line.indexOf(' '); if (sp < 0) return;
  const e = line.slice(0, sp), words = line.slice(sp + 1);
  ALL.push({ e, name: words.split(' ')[0], kw: words.toLowerCase(), cat: CATS[CATS.length - 1] });
});
const CAT_ICON = { 'Smileys': '😀', 'Gestures & people': '👋', 'Animals & nature': '🐻', 'Food & drink': '🍔', 'Activities': '⚽', 'Travel & places': '🚀', 'Objects': '💡', 'Symbols': '❤️', 'Flags': '🏁' };

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>
    :host {
      display: none; position: absolute; z-index: 20; width: var(--ep-width, 300px); box-sizing: border-box;
      background: var(--ep-bg, #fff); border: 1px solid var(--ep-border, #d6dae0); border-radius: 12px;
      box-shadow: 0 10px 32px rgba(20,18,40,.18); font-family: inherit; font-size: 13px; color: #1f2328;
      text-align: left; cursor: default;
    }
    :host([open]) { display: block; }
    :host([inline]) { display: block; position: static; width: 100%; border: 0; box-shadow: none; border-radius: 0; }
    #search { display: block; width: calc(100% - 16px); margin: 8px; padding: 6px 9px; box-sizing: border-box; border: 1px solid #d6dae0; border-radius: 8px; font: inherit; font-size: 13px; outline: none; }
    #search:focus { border-color: var(--ep-accent, #6b3fd6); }
    #cats { display: flex; gap: 1px; padding: 0 6px; border-bottom: 1px solid #eef0f3; }
    #cats button { flex: 1; border: 0; background: none; padding: 5px 0 6px; font-size: 15px; cursor: pointer; border-bottom: 2px solid transparent; border-radius: 0; opacity: .7; }
    #cats button:hover { opacity: 1; background: #f6f7f9; }
    #cats button.on { opacity: 1; border-bottom-color: var(--ep-accent, #6b3fd6); }
    #list { height: 236px; overflow-y: auto; padding: 4px 6px 8px; }
    .h { font-size: 10.5px; font-weight: 650; text-transform: uppercase; letter-spacing: .04em; color: #79808a; padding: 8px 4px 3px; }
    .grid { display: grid; grid-template-columns: repeat(var(--_cols, 8), 1fr); }
    .grid button { border: 0; background: none; padding: 0; height: 34px; font-size: 21px; line-height: 1; border-radius: 8px; cursor: pointer; }
    .grid button:hover, .grid button:focus { background: #f0f2f4; outline: none; }
    #none { padding: 14px 8px; color: #79808a; font-size: 12.5px; }
    #none b { font-weight: 600; color: #1f2328; }
    #none button { margin-top: 6px; padding: 4px 10px; border-radius: 8px; border: 1px solid #d6dae0; background: #fff; font: inherit; font-size: 12px; cursor: pointer; }
    #foot { display: flex; align-items: center; gap: 8px; min-height: 30px; padding: 4px 10px; border-top: 1px solid #eef0f3; font-size: 12px; color: #57606a; }
    #foot .big { font-size: 20px; }
    #cats button.custom { font-size: 11.5px; font-weight: 650; letter-spacing: .02em; color: #57606a; }
    #custom { display: none; height: 236px; padding: 14px 12px; box-sizing: border-box; }
    #custom[open] { display: block; }
    #custom p { margin: 0 0 10px; font-size: 12.5px; color: #57606a; line-height: 1.5; }
    #custom .row { display: flex; gap: 6px; }
    #custom input { flex: 1; min-width: 0; padding: 7px 10px; border: 1px solid #d6dae0; border-radius: 8px; font: inherit; font-size: 15px; outline: none; }
    #custom input:focus { border-color: var(--ep-accent, #6b3fd6); }
    #custom button { padding: 6px 12px; border-radius: 8px; border: 1px solid var(--ep-accent, #6b3fd6); background: var(--ep-accent, #6b3fd6); color: #fff; font: inherit; font-size: 12.5px; cursor: pointer; }
    #custom button:disabled { opacity: .4; cursor: default; }
    #custom .preview { margin-top: 14px; font-size: 30px; min-height: 40px; text-align: center; word-break: break-all; }
  </style>
  <input id="search" placeholder="Search emoji" spellcheck="false" autocomplete="off">
  <div id="cats"></div>
  <div id="list"></div>
  <div id="custom">
    <p>A reaction is any string. Paste an emoji that is not listed, a <code>:shortcode:</code>, or a word.</p>
    <div class="row">
      <input id="custom-in" placeholder="type or paste" spellcheck="false" autocomplete="off">
      <button id="custom-go" disabled>Send</button>
    </div>
    <div class="preview" id="custom-prev"></div>
  </div>
  <div id="foot"><span class="big"></span><span class="nm">pick one, or type to search</span></div>
`;

class EmojiPicker extends HTMLElement {
  static get observedAttributes() { return ['open', 'columns']; }
  #recent = [];
  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
    const $ = (id) => this.shadowRoot.getElementById(id);
    const cats = $('cats');
    CATS.forEach((c) => {
      const b = document.createElement('button'); b.textContent = CAT_ICON[c] || c.charAt(0); b.title = c;
      b.addEventListener('click', (e) => { e.stopPropagation(); $('search').value = ''; this.#showCustom(false); this.#render(); this.#jump(c); });
      cats.appendChild(b);
    });
    const ct = document.createElement('button'); ct.className = 'custom'; ct.textContent = 'custom'; ct.title = 'Custom';
    ct.addEventListener('click', (e) => { e.stopPropagation(); this.#showCustom(true); });
    cats.appendChild(ct);
    $('search').addEventListener('input', () => { this.#showCustom(false); this.#render(); });
    $('search').addEventListener('keydown', (e) => {
      e.stopPropagation();
      if (e.key === 'Escape') { this.close(); return; }
      if (e.key === 'Enter') {
        const first = $('list').querySelector('.grid button');
        if (first) this.#pick(first.dataset.e, first.title);
        else if ($('search').value.trim()) this.#pick($('search').value.trim(), 'custom');
      }
    });
    $('list').addEventListener('scroll', () => this.#syncCat());
    // the custom row: anything at all, sent as-is
    const cin = $('custom-in'), cgo = $('custom-go');
    cin.addEventListener('input', () => { cgo.disabled = !cin.value.trim(); $('custom-prev').textContent = cin.value.trim(); });
    cin.addEventListener('keydown', (e) => { e.stopPropagation(); if (e.key === 'Enter' && cin.value.trim()) { const v = cin.value.trim(); cin.value = ''; cgo.disabled = true; this.#pick(v, 'custom'); } if (e.key === 'Escape') this.close(); });
    cgo.addEventListener('click', (e) => { e.stopPropagation(); const v = cin.value.trim(); if (!v) return; cin.value = ''; cgo.disabled = true; this.#pick(v, 'custom'); });
    this.addEventListener('click', (e) => e.stopPropagation());
    this.addEventListener('mouseover', (e) => {
      const b = e.target.closest && e.target.closest('.grid button'); if (!b) return;
      $('foot').querySelector('.big').textContent = b.dataset.e; $('foot').querySelector('.nm').textContent = b.title;
    });
    this._onDoc = (e) => { if (this.hasAttribute('inline')) return; if (this.hasAttribute('open') && !e.composedPath().includes(this)) this.close(); };
  }
  connectedCallback() {
    try { this.#recent = JSON.parse(localStorage.getItem(this.#key()) || '[]'); } catch (e) { this.#recent = []; }
    if (!Array.isArray(this.#recent)) this.#recent = [];
    this.style.setProperty('--_cols', this.getAttribute('columns') || '8');
    this.#render();
    document.addEventListener('click', this._onDoc);
  }
  disconnectedCallback() { document.removeEventListener('click', this._onDoc); }
  attributeChangedCallback(n) {
    if (n === 'columns') this.style.setProperty('--_cols', this.getAttribute('columns') || '8');
    if (n === 'open' && this.hasAttribute('open') && this.isConnected) { this.#render(); this.focus(); }
  }
  #key() { return this.getAttribute('persist') || 'emoji-recent'; }
  open() { this.setAttribute('open', ''); }
  close() {
    if (!this.hasAttribute('open') && !this.hasAttribute('inline')) return;
    this.removeAttribute('open');
    this.dispatchEvent(new CustomEvent('ep-close', { bubbles: true, composed: true }));
  }
  toggle() { if (this.hasAttribute('open')) this.close(); else this.open(); }
  focus() { const s = this.shadowRoot.getElementById('search'); s.value = ''; this.#showCustom(false); this.#render(); setTimeout(() => s.focus(), 0); }
  #pick(e, name) {
    this.#recent = [e].concat(this.#recent.filter((x) => x !== e)).slice(0, 24);
    try { localStorage.setItem(this.#key(), JSON.stringify(this.#recent)); } catch (x) {}
    this.dispatchEvent(new CustomEvent('ep-pick', { detail: { emoji: e, name }, bubbles: true, composed: true }));
    if (!this.hasAttribute('inline')) this.close();
  }
  #grid(items) {
    const g = document.createElement('div'); g.className = 'grid';
    items.forEach((it) => {
      const b = document.createElement('button'); b.textContent = it.e; b.title = it.name; b.dataset.e = it.e;
      b.addEventListener('click', (e) => { e.stopPropagation(); this.#pick(it.e, it.name); });
      g.appendChild(b);
    });
    return g;
  }
  #render() {
    const $ = (id) => this.shadowRoot.getElementById(id);
    const list = $('list'); list.textContent = '';
    const q = $('search').value.trim().toLowerCase();
    if (q) {
      const raw = $('search').value.trim();
      const hits = ALL.filter((it) => it.kw.indexOf(q) >= 0 || it.e === q);
      if (hits.length) list.appendChild(this.#grid(hits.slice(0, 120)));
      // anything typed can be sent as-is (a reaction is any string)
      const none = document.createElement('div'); none.id = 'none';
      none.textContent = hits.length ? '' : 'nothing named that. ';
      const b = document.createElement('button'); b.textContent = 'use "' + raw + '" as-is';
      b.addEventListener('click', (e) => { e.stopPropagation(); this.#pick(raw, 'custom'); });
      none.appendChild(b); list.appendChild(none);
      return;
    }
    if (this.#recent.length) {
      const h = document.createElement('div'); h.className = 'h'; h.textContent = 'Recent'; h.dataset.cat = 'Recent'; list.appendChild(h);
      list.appendChild(this.#grid(this.#recent.map((e) => ALL.find((it) => it.e === e) || { e, name: e })));
    }
    CATS.forEach((c) => {
      const h = document.createElement('div'); h.className = 'h'; h.textContent = c; h.dataset.cat = c; list.appendChild(h);
      list.appendChild(this.#grid(ALL.filter((it) => it.cat === c)));
    });
    this.#syncCat();
  }
  #showCustom(on) {
    const $ = (id) => this.shadowRoot.getElementById(id);
    $('custom').toggleAttribute('open', on);
    $('list').style.display = on ? 'none' : '';
    this.shadowRoot.querySelectorAll('#cats button').forEach((b) => b.classList.toggle('on', on ? b.classList.contains('custom') : false));
    if (on) setTimeout(() => $('custom-in').focus(), 0);
    else this.#syncCat();
  }
  #jump(c) {
    const h = [...this.shadowRoot.querySelectorAll('#list .h')].find((x) => x.dataset.cat === c);
    if (h) h.scrollIntoView({ block: 'start' });
  }
  #syncCat() {
    const list = this.shadowRoot.getElementById('list');
    const edge = list.getBoundingClientRect().top + 12;
    let cur = null;
    // measured against the list's own top edge (offsetTop would be
    // relative to some other ancestor, and pick the header before)
    this.shadowRoot.querySelectorAll('#list .h').forEach((h) => { if (h.getBoundingClientRect().top <= edge) cur = h.dataset.cat; });
    if (this.shadowRoot.getElementById('custom').hasAttribute('open')) return;
    this.shadowRoot.querySelectorAll('#cats button').forEach((b) => b.classList.toggle('on', b.title === cur));
  }
}
customElements.define('emoji-picker', EmojiPicker);
