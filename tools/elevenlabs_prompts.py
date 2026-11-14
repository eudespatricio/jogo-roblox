"""Prompts e parametros ElevenLabs Sound Effects (`eleven_text_to_sound_v2`) para os 56 cues da MURALHA."""

from __future__ import annotations

ELEVENLABS_MODEL_ID = "eleven_text_to_sound_v2"

ELEVENLABS_PROMPTS: dict[str, dict[str, object]] = {
    # Traps & sinergias
    "archer_fire": {
        "prompt": "Dry close-mic medieval bowstring twang releasing a fast feathered arrow whoosh, single crisp one-shot game foley, no background music",
        "api_duration": 0.5,
        "max_duration": 0.36,
        "prompt_influence": 0.70,
    },
    "archer_impact": {
        "prompt": "Dry close-mic arrow thud piercing leather and wood shield with crisp fletching rattle, single clean one-shot game foley",
        "api_duration": 0.5,
        "max_duration": 0.34,
        "prompt_influence": 0.70,
    },
    "tar_fire": {
        "prompt": "Heavy cauldron tipping thick boiling pitch splash followed by thick tar splatter on stone, single one-shot fantasy game foley",
        "api_duration": 0.8,
        "max_duration": 0.78,
        "prompt_influence": 0.65,
    },
    "tar_ignite": {
        "prompt": "Sudden rushing fire whoosh igniting oil with bright crackling flames, dry close-mic one-shot game foley, no music",
        "api_duration": 0.95,
        "max_duration": 0.95,
        "prompt_influence": 0.65,
    },
    "frost_fire": {
        "prompt": "Sharp magical ice shard burst with crystalline frost wind whoosh and shimmering chime, dry game foley one-shot",
        "api_duration": 0.8,
        "max_duration": 0.75,
        "prompt_influence": 0.65,
    },
    "frost_impact": {
        "prompt": "Crisp frozen crystal spike impact and rapid ice freezing crackle, single clean one-shot game sound effect",
        "api_duration": 0.7,
        "max_duration": 0.65,
        "prompt_influence": 0.65,
    },
    "syn_thermal_shock": {
        "prompt": "Explosive thermal shock steam hiss blended with shattering frozen crystal and deep bass crack, fantasy game SFX one-shot",
        "api_duration": 0.9,
        "max_duration": 0.88,
        "prompt_influence": 0.65,
    },
    "cannon_fire": {
        "prompt": "Massive medieval iron fortress cannon blast with punchy black powder boom and short tight tail, dry game SFX one-shot",
        "api_duration": 1.15,
        "max_duration": 1.15,
        "prompt_influence": 0.70,
    },
    "cannon_impact": {
        "prompt": "Heavy iron cannonball explosion cratering stone and wood debris, punchy low-end one-shot game sound effect",
        "api_duration": 1.0,
        "max_duration": 0.98,
        "prompt_influence": 0.70,
    },
    "catapult_fire": {
        "prompt": "Wooden siege catapult arm snapping loose with taut rope creak and heavy boulder whoosh, single game foley one-shot",
        "api_duration": 0.9,
        "max_duration": 0.88,
        "prompt_influence": 0.65,
    },
    "catapult_impact": {
        "prompt": "Massive stone boulder smashing into castle rampart with tumbling rock rubble, dry close-mic game SFX one-shot",
        "api_duration": 1.1,
        "max_duration": 1.10,
        "prompt_influence": 0.70,
    },
    # Build / economia
    "build_place": {
        "prompt": "Crisp heavy stone and timber block locking solidly into place on a fortress wall, tactile game UI construction one-shot",
        "api_duration": 0.55,
        "max_duration": 0.42,
        "prompt_influence": 0.70,
    },
    "build_move": {
        "prompt": "Quick clean wooden slide and mechanical stone latch click, light tactile strategy game SFX one-shot",
        "api_duration": 0.5,
        "max_duration": 0.36,
        "prompt_influence": 0.70,
    },
    "build_remove": {
        "prompt": "Short hollow wooden dismantle thump and sliding stone unlatch, clean strategy game UI one-shot",
        "api_duration": 0.55,
        "max_duration": 0.44,
        "prompt_influence": 0.70,
    },
    "build_upgrade_2": {
        "prompt": "Craftsman hammer strike on iron anvil followed by rising warm brass chime, game tower upgrade level 2 one-shot",
        "api_duration": 0.75,
        "max_duration": 0.72,
        "prompt_influence": 0.65,
    },
    "build_upgrade_3": {
        "prompt": "Bright double anvil forge ring and uplifting triumphant harmonic chord chime, tower upgrade tier 3 game SFX",
        "api_duration": 0.9,
        "max_duration": 0.90,
        "prompt_influence": 0.65,
    },
    "build_upgrade_4": {
        "prompt": "Resonant tempered steel hammer forge strike with shimmering golden crystal arpeggio, tier 4 game upgrade SFX",
        "api_duration": 1.0,
        "max_duration": 1.00,
        "prompt_influence": 0.65,
    },
    "build_upgrade_5": {
        "prompt": "Grand masterwork forge anvil clang blossoming into majestic warm brass and bell fanfare chord, max tier upgrade SFX",
        "api_duration": 1.2,
        "max_duration": 1.20,
        "prompt_influence": 0.65,
    },
    "build_invalid": {
        "prompt": "Soft dull muted wooden double-tap error tone, gentle low strategy UI negative feedback one-shot, not harsh",
        "api_duration": 0.5,
        "max_duration": 0.34,
        "prompt_influence": 0.70,
    },
    "build_locked": {
        "prompt": "Heavy iron padlock bolt rattling shut with metallic clank, clean medieval UI locked one-shot",
        "api_duration": 0.6,
        "max_duration": 0.50,
        "prompt_influence": 0.70,
    },
    "coin_gain": {
        "prompt": "Bright sparkling handful of medieval gold coins clinking crisply in sequence, clean rewarding game UI one-shot",
        "api_duration": 0.65,
        "max_duration": 0.60,
        "prompt_influence": 0.70,
    },
    "coin_spend": {
        "prompt": "Crisp leather pouch clink of two gold coins dropping onto wooden merchant counter, clean game UI one-shot",
        "api_duration": 0.55,
        "max_duration": 0.45,
        "prompt_influence": 0.70,
    },
    # Batalha
    "horde_spawn": {
        "prompt": "Ominous deep dark stone rift portal opening with low sub rumble and crackling violet arcane energy, game wave spawn SFX",
        "api_duration": 1.7,
        "max_duration": 1.75,
        "prompt_influence": 0.65,
    },
    "death_runner": {
        "prompt": "Quick light monster grunt and crisp leather armor poof dissolving into mist, dry close-mic game enemy defeat SFX",
        "api_duration": 0.55,
        "max_duration": 0.48,
        "prompt_influence": 0.65,
    },
    "death_brute": {
        "prompt": "Deep monstrous brute growl collapsing heavily in iron plate armor onto stone floor, game enemy defeat one-shot",
        "api_duration": 0.9,
        "max_duration": 0.92,
        "prompt_influence": 0.65,
    },
    "death_swarm": {
        "prompt": "Tiny crisp insectoid pop and airy magical burst fizz, fast micro game enemy defeat one-shot",
        "api_duration": 0.5,
        "max_duration": 0.32,
        "prompt_influence": 0.65,
    },
    "wall_hit": {
        "prompt": "Heavy battering ram thud slamming against thick castle stone masonry wall, punchy game defense SFX one-shot",
        "api_duration": 0.7,
        "max_duration": 0.68,
        "prompt_influence": 0.70,
    },
    "wall_alarm": {
        "prompt": "Urgent bronze castle watchtower bell double toll warning of wall breach, dramatic medieval game alert one-shot",
        "api_duration": 1.3,
        "max_duration": 1.35,
        "prompt_influence": 0.65,
    },
    "wall_heartbeat": {
        "prompt": "Deep tense muffled double heartbeat thump pulse with subtle dark sub resonance, dramatic low-health game cue",
        "api_duration": 0.95,
        "max_duration": 0.95,
        "prompt_influence": 0.70,
    },
    "gate_fracture": {
        "prompt": "Heavy reinforced oak castle gate splintering and iron hinges cracking apart under siege, dramatic game foley one-shot",
        "api_duration": 1.65,
        "max_duration": 1.70,
        "prompt_influence": 0.65,
    },
    "horn": {
        "prompt": "Bold deep medieval brass war horn blast echoing across a castle valley, heroic siege start call, no background drums",
        "api_duration": 1.55,
        "max_duration": 1.60,
        "prompt_influence": 0.70,
    },
    "victory_sting": {
        "prompt": "Triumphant heroic medieval brass horns and snare roll victory fanfare stinger, bright D major resolution, clean ending",
        "api_duration": 2.6,
        "max_duration": 2.65,
        "prompt_influence": 0.70,
    },
    "defeat_sting": {
        "prompt": "Somber tragic low medieval brass and cellos descending minor defeat stinger with soft timpani roll, clean fade out",
        "api_duration": 2.7,
        "max_duration": 2.75,
        "prompt_influence": 0.70,
    },
    # UI
    "ui_click": {
        "prompt": "Clean short wooden button tap, crisp minimal mobile game UI click one-shot, dry zero reverb",
        "api_duration": 0.5,
        "max_duration": 0.14,
        "prompt_influence": 0.75,
    },
    "ui_toggle": {
        "prompt": "Crisp smooth mechanical brass switch toggle click up, clean responsive mobile game UI sound, dry zero reverb",
        "api_duration": 0.5,
        "max_duration": 0.20,
        "prompt_influence": 0.75,
    },
    # Fisica
    "phys_wood_impact": {
        "prompt": "Dry close-mic heavy oak plank wood collision thud, single crisp one-shot game physics foley",
        "api_duration": 0.5,
        "max_duration": 0.34,
        "prompt_influence": 0.70,
    },
    "phys_stone_impact": {
        "prompt": "Heavy carved granite stone block impact crack with tiny pebble settle, single dry game physics foley one-shot",
        "api_duration": 0.6,
        "max_duration": 0.50,
        "prompt_influence": 0.70,
    },
    "phys_iron_impact": {
        "prompt": "Solid forged iron blade clanging against steel armor with tight damped ring, single dry game physics foley one-shot",
        "api_duration": 0.55,
        "max_duration": 0.45,
        "prompt_influence": 0.70,
    },
    "phys_ice_shatter": {
        "prompt": "Crisp brittle ice block shattering into sparkling shards on stone, clean one-shot game physics foley",
        "api_duration": 0.6,
        "max_duration": 0.52,
        "prompt_influence": 0.70,
    },
    # Bosses, Campanha & Torcida
    "boss_intro": {
        "prompt": "Terrifying colossal siege titan roar rising from deep brass braam and earth-shaking rumble, epic boss entrance SFX",
        "api_duration": 2.05,
        "max_duration": 2.10,
        "prompt_influence": 0.65,
    },
    "boss_telegraph": {
        "prompt": "Menacing rising metallic charge whine and dark bronze warning chime before boss heavy strike, game combat telegraph",
        "api_duration": 1.05,
        "max_duration": 1.05,
        "prompt_influence": 0.65,
    },
    "boss_slam": {
        "prompt": "Earth-shattering colossal warhammer ground slam shockwave cracking castle stone beneath it, heavy boss impact SFX",
        "api_duration": 1.25,
        "max_duration": 1.28,
        "prompt_influence": 0.70,
    },
    "boss_stagger": {
        "prompt": "Heavy armored boss knee buckling with metallic shield break crack and exhausted low groan, game combat stagger SFX",
        "api_duration": 1.15,
        "max_duration": 1.15,
        "prompt_influence": 0.65,
    },
    "boss_enrage": {
        "prompt": "Furious monstrous boss battle roar surging with blazing fire whoosh and metallic war rattle, game phase 2 enrage SFX",
        "api_duration": 1.4,
        "max_duration": 1.45,
        "prompt_influence": 0.65,
    },
    "boss_death": {
        "prompt": "Colossal stone and iron boss disintegrating in a deep sub-bass explosion with crumbling armor collapse, epic defeat SFX",
        "api_duration": 2.0,
        "max_duration": 2.05,
        "prompt_influence": 0.65,
    },
    "campaign_select": {
        "prompt": "Warm parchment map scroll flick with crisp golden wax seal stamp tap, fantasy campaign UI select SFX",
        "api_duration": 0.5,
        "max_duration": 0.34,
        "prompt_influence": 0.70,
    },
    "campaign_star": {
        "prompt": "Radiant crystalline chime bell sparkle ascending warmly, rewarding mobile game star earned SFX one-shot",
        "api_duration": 0.68,
        "max_duration": 0.65,
        "prompt_influence": 0.70,
    },
    "campaign_act_clear": {
        "prompt": "Grand uplifting medieval orchestral brass and harp triumph fanfare celebrating act completion, clean resolving finale",
        "api_duration": 2.4,
        "max_duration": 2.45,
        "prompt_influence": 0.70,
    },
    "crowd_murmur": {
        "prompt": "Restless medieval fortress garrison crowd murmuring softly in anticipation, clean stereo stadium ambience swell",
        "api_duration": 1.6,
        "max_duration": 1.60,
        "prompt_influence": 0.65,
    },
    "crowd_cheer": {
        "prompt": "Energetic cheering medieval castle defenders roaring with excitement and clapping, clean one-shot crowd reaction",
        "api_duration": 1.55,
        "max_duration": 1.55,
        "prompt_influence": 0.65,
    },
    "crowd_gasp": {
        "prompt": "Shocked collective crowd gasp inhaling sharply in sudden tension, clean close studio reaction SFX",
        "api_duration": 1.1,
        "max_duration": 1.10,
        "prompt_influence": 0.65,
    },
    "crowd_victory": {
        "prompt": "Jubilant castle garrison crowd cheering wildly with triumphant shouts and applause after victory, clean fade",
        "api_duration": 2.1,
        "max_duration": 2.15,
        "prompt_influence": 0.65,
    },
    # Stems BGM seamless (mesma paleta tonal em Re / 110 BPM)
    "bgm_bastion": {
        "prompt": "Seamless instrumental medieval fortress preparation loop at 110 BPM in D Dorian, warm lute, soft wooden hand drums, subtle low cello drone, calm heroic strategy build atmosphere, no vocals",
        "api_duration": 16.50,
        "max_duration": 16.00,
        "prompt_influence": 0.65,
    },
    "bgm_siege": {
        "prompt": "Seamless instrumental epic medieval siege battle music loop at 110 BPM in D minor, driving cinematic war drums, rhythmic cellos, heroic brass stabs, intense tower defense energy, no vocals",
        "api_duration": 15.05,
        "max_duration": 14.55,
        "prompt_influence": 0.65,
    },
    "bgm_siege_2": {
        "prompt": "Seamless instrumental dark-fantasy siege combat loop at 110 BPM in D minor, tribal taiko drums, fast medieval lute and hurdy-gurdy riff, tense orchestral strings, deep war horn stabs, no vocals",
        "api_duration": 15.05,
        "max_duration": 14.55,
        "prompt_influence": 0.65,
    },
    "bgm_danger": {
        "prompt": "Seamless instrumental urgent castle breach tension loop at 110 BPM in D minor, pounding war taiko drums, fast nervous staccato strings, tense low horn ostinato, high stakes defense, no vocals",
        "api_duration": 15.05,
        "max_duration": 14.55,
        "prompt_influence": 0.65,
    },
    "bgm_boss": {
        "prompt": "Seamless instrumental colossal raid boss battle theme loop at 110 BPM in D Phrygian, thunderous cinematic percussion, fierce low brass braams, aggressive bowed strings, dark fantasy climax, no vocals",
        "api_duration": 15.05,
        "max_duration": 14.55,
        "prompt_influence": 0.65,
    },
}

ELEVENLABS_TTS_MODEL_ID = "eleven_multilingual_v2"

_BOSS_VO_SPECS: dict[str, dict[str, object]] = {
    "vo_boss_iron_ram_intro": {
        "voice_id": "nPczCjzI2devNBz1zQrb",
        "texts": {
            "pt": "Pedra e madeira? Meu aríete vai reduzir sua muralha a pó!",
            "en": "Stone and timber? My battering ram will smash your wall to dust!",
            "es": "¿Piedra y madera? ¡Mi ariete reducirá tu muralla a polvo!",
        },
        "pitch_st": -2.0,
        "sub_db": -13.0,
        "echo_ms": 28,
        "echo_db": -14.0,
        "low_boost_db": 3.0,
    },
    "vo_boss_iron_ram_enrage": {
        "voice_id": "nPczCjzI2devNBz1zQrb",
        "texts": {
            "pt": "Ferro em carga máxima! Derrubem esse portão!",
            "en": "Full iron charge! Tear down that gate!",
            "es": "¡Carga máxima de hierro! ¡Derriben ese portón!",
        },
        "pitch_st": -2.0,
        "sub_db": -12.0,
        "echo_ms": 28,
        "echo_db": -14.0,
        "low_boost_db": 3.0,
    },
    "vo_boss_slag_intro": {
        "voice_id": "SOYHLrjzK2X1ezoPC6cr",
        "texts": {
            "pt": "A forja ferve! Vou derreter cada bloco desse bastião!",
            "en": "The furnace boils! I will melt every stone of this bastion!",
            "es": "¡La forja arde! ¡Derretiré cada bloque de este bastión!",
        },
        "pitch_st": -1.8,
        "sub_db": -13.5,
        "echo_ms": 24,
        "echo_db": -15.0,
        "drive_db": 3.5,
    },
    "vo_boss_slag_enrage": {
        "voice_id": "SOYHLrjzK2X1ezoPC6cr",
        "texts": {
            "pt": "Pressão no limite! Queimem sob a escória!",
            "en": "Maximum pressure! Burn beneath the molten slag!",
            "es": "¡Presión al límite! ¡Ardan bajo la escoria!",
        },
        "pitch_st": -1.8,
        "sub_db": -12.5,
        "echo_ms": 24,
        "echo_db": -15.0,
        "drive_db": 4.0,
    },
    "vo_boss_rime_intro": {
        "voice_id": "pFZP5JQG7iQjIQuC4Bku",
        "texts": {
            "pt": "Ajoelhem-se no gelo... o inverno veio calar suas torres!",
            "en": "Kneel before the frost... winter has come to silence your towers!",
            "es": "Arrodíllense ante el hielo... ¡el invierno vino a silenciar sus torres!",
        },
        "pitch_st": -0.5,
        "sub_db": None,
        "echo_ms": 36,
        "echo_db": -10.5,
        "air_boost_db": 3.0,
    },
    "vo_boss_rime_enrage": {
        "voice_id": "pFZP5JQG7iQjIQuC4Bku",
        "texts": {
            "pt": "Nevasca eterna! Congelem até a alma!",
            "en": "Eternal blizzard! Freeze to the very soul!",
            "es": "¡Ventisca eterna! ¡Congélense hasta el alma!",
        },
        "pitch_st": -0.5,
        "sub_db": None,
        "echo_ms": 36,
        "echo_db": -10.0,
        "air_boost_db": 3.5,
    },
    "vo_boss_powder_intro": {
        "voice_id": "N2lVS1w4EtoT3dr4eOWO",
        "texts": {
            "pt": "Acendam os pavios! Hoje essa fortaleza sobe pelos ares!",
            "en": "Light the fuses! Tonight this fortress blows sky high!",
            "es": "¡Enciendan las mechas! ¡Hoy esta fortaleza vuela por los aires!",
        },
        "pitch_st": -0.8,
        "sub_db": None,
        "echo_ms": 20,
        "echo_db": -16.0,
        "mid_boost_db": 2.5,
    },
    "vo_boss_powder_enrage": {
        "voice_id": "N2lVS1w4EtoT3dr4eOWO",
        "texts": {
            "pt": "Dobrem a pólvora! Fogo em todas as linhas!",
            "en": "Double the powder! Fire across every lane!",
            "es": "¡Doblen la pólvora! ¡Fuego en todas las líneas!",
        },
        "pitch_st": -0.8,
        "sub_db": None,
        "echo_ms": 20,
        "echo_db": -16.0,
        "mid_boost_db": 3.0,
    },
    "vo_boss_rift_intro": {
        "voice_id": "pNInz6obpgDQGcFmaJgB",
        "texts": {
            "pt": "Eu sou o abismo da Fenda... nenhuma muralha resiste ao meu despertar!",
            "en": "I am the abyss of the Rift... no bastion survives my awakening!",
            "es": "Soy el abismo de la Grieta... ¡ninguna muralla resiste mi despertar!",
        },
        "pitch_st": -2.8,
        "sub_db": -9.5,
        "echo_ms": 42,
        "echo_db": -11.5,
        "low_boost_db": 3.5,
    },
    "vo_boss_rift_enrage": {
        "voice_id": "pNInz6obpgDQGcFmaJgB",
        "texts": {
            "pt": "A Fenda se abre! Tudo será devorado!",
            "en": "The Rift tears open! Everything will be devoured!",
            "es": "¡La Grieta se abre! ¡Todo será devorado!",
        },
        "pitch_st": -2.8,
        "sub_db": -9.0,
        "echo_ms": 42,
        "echo_db": -11.0,
        "low_boost_db": 3.5,
    },
}


def _build_boss_voice_lines() -> dict[str, dict[str, object]]:
    """Expand per-boss specs into unsuffixed PT-BR cues plus _en/_es trilingual cues."""
    out: dict[str, dict[str, object]] = {}
    for base_cue, base_spec in _BOSS_VO_SPECS.items():
        texts = base_spec["texts"]
        shared = {k: v for k, v in base_spec.items() if k != "texts"}
        for loc, text in texts.items():  # type: ignore[union-attr]
            cue_name = base_cue if loc == "pt" else f"{base_cue}_{loc}"
            out[cue_name] = {**shared, "locale": loc, "text": text}
    return out


BOSS_VOICE_LINES: dict[str, dict[str, object]] = _build_boss_voice_lines()
