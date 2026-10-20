"""USDA FNDDS 2021-2023 survey foods (foods and dishes as eaten): see fdc.py. WWEIA 3000s are mixed dishes,
sandwiches, pizza and soups."""

from readers.fdc import read_set


def read(data):
    yield from read_set(data, "usda_fndds", {str(c) for c in range(3000, 3900)})
