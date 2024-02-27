from collections.optional import Optional

from dainemo.autograd import Symbol
from dainemo.autograd.ops import OP


@value
struct Node(CollectionElement, Stringable):
    var operator: OP
    var output: Symbol
    var input_1: Symbol
    var input_2: Optional[Symbol]
    
    fn __init__(inout self, operator: OP, output: Symbol, input_1: Symbol, input_2: Optional[Symbol]):
        self.operator = operator
        self.output = output  
        self.input_1 = input_1
        self.input_2 = input_2  

    fn __str__(self) -> String:
        return self.json()

    fn json(self) -> String:
        var s: String = "{\"operator\": \"" + str(self.operator.name) + "\", \"inputs\": ["
        s += self.input_1.json() 
        if self.input_2:
            s += ", " + self.input_2.value().json()
        s += "], \"outputs\": ["
        s += self.output.json() + "]}"
        return  s