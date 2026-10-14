#!/usr/bin/env bash
# Erzeugt config/application.properties und lädt Schema/Seed aus dem gepinnten cBioPortal-Image (siehe .env).
for d in config data; do
    (cd "$d" && ./init.sh)
done
