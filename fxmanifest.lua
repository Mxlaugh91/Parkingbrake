fx_version 'cerulean'
game 'gta5'

description 'qbx_parkingbrake - Synced parking brake for Qbox'
author 'Gemini CLI'
version '1.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'locales/*.json',
    'data/audioexample_sounds.dat54.rel',
    'audiodirectory/custom_sounds.awc'
}

data_file 'AUDIO_WAVEPACK'  'audiodirectory'
data_file 'AUDIO_SOUNDDATA' 'data/audioexample_sounds.dat'

dependencies {
    'ox_lib',
    'qbx_core'
}

lua54 'yes'
