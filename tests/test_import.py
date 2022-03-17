import sys
sys.path.append('.')


def test_import():
    import poxo

def test_import_series():
    from poxo import Series
    s = Series()

def test_import_dataframe():
    from poxo import DataFrame
    df = DataFrame()
