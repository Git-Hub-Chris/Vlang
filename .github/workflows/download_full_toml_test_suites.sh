#!/usr/bin/env bash

rm -rf vlib/toml/tests/testdata/tt
rm -rf vlib/toml/tests/testdata/iarna
rm -rf vlib/toml/tests/testdata/large_toml_file_test.toml

.github/workflows/retry.sh wget https://gist.githubusercontent.com/Larpon/89b0e3d94c6903851ff15559e5df7a05/raw/62a1f87a4e37bf157f2e0bfb32d85d840c98e422/large_toml_file_test.toml -O vlib/toml/tests/testdata/large_toml_file_test.toml

.github/workflows/retry.sh git clone -n https://github.com/iarna/toml-spec-tests.git vlib/toml/tests/testdata/iarna
git -C vlib/toml/tests/testdata/iarna checkout 1880b1a

.github/workflows/retry.sh git clone -n https://github.com/toml-lang/toml-test.git vlib/toml/tests/testdata/tt
git -C vlib/toml/tests/testdata/tt checkout f30c716
