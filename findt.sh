#!/bin/bash

sudo find . -type f -name "*.$1" -exec grep -i "$2" {} +
