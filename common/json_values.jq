# Value predicates shared by provider schemas. No endpoints or provider fields.
def text_or_null($value; $max):
  $value == null or
    (($value | type) == "string" and ($value | length) <= $max and
      ($value | test("[\u0000-\u001f\u007f]") | not));

def integer_or_null($value; $min; $max):
  $value == null or
    (($value | type) == "number" and ($value | floor) == $value and
      $value >= $min and $value <= $max);
