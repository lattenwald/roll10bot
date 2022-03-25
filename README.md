# Roller

## Build

    ./build.sh

## Configure

Put your bot token into `config.toml` (see example `config.toml.example`).

## Run

    ./run.sh

## Use

It's an inline telegram bot. Call it in any chat just mentioning your bot (i.e. print `@roll10bot`) and wait for suggestion to roll plain d10, click it.
Mention bot with dice number (i.e. `@roll10bot 5`) and click one of suggestions. Result is calculated by World of Darkness rules: 8, 9, 10 is a success, 1 is a failure.

Bot talks Russian.
