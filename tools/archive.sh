#!/bin/bash
git archive --format=tar --prefix=cpu8080-0.1/ HEAD | gzip >cpu8080-0.1.tar.gz
