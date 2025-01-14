from math import max
from memory.anypointer import AnyPointer

from basalt import Tensor, TensorShape, Symbol


struct Collection(CollectionElement, Sized):
    """
    A collection of tensors with associated symbols.
    """

    var size: Int
    var capacity: Int
    var data: AnyPointer[Tensor[dtype]]
    var symbols: DTypePointer[DType.uint32]

    @always_inline("nodebug")
    fn __init__(inout self, *, capacity: Int = 0):
        """
        Initializes a new Collection with the given capacity.
        """
        self.size = 0
        self.capacity = capacity
        self.data = AnyPointer[Tensor[dtype]].alloc(capacity)
        self.symbols = DTypePointer[DType.uint32].alloc(capacity)

    @always_inline("nodebug")
    fn __moveinit__(inout self, owned existing: Self):
        """
        Move initializes a Collection from an existing one.
        """
        self.size = existing.size
        self.capacity = existing.capacity
        self.data = existing.data
        self.symbols = existing.symbols

    @always_inline("nodebug")
    fn __copyinit__(inout self, existing: Self):
        """
        Copy initializes a Collection from an existing one.
        """
        self.capacity = existing.capacity
        self.size = existing.size
        self.data = AnyPointer[Tensor[dtype]].alloc(existing.capacity)
        self.symbols = DTypePointer[DType.uint32].alloc(existing.capacity)
        memcpy(self.symbols, existing.symbols, existing.capacity)

        for i in range(existing.size):
            (self.data + i).emplace_value((existing.data + i)[])

    @always_inline("nodebug")
    fn __del__(owned self):
        """
        Destructor for the Collection.
        """
        for i in range(self.size):
            _ = (self.data + i).take_value()
        if self.data:
            self.data.free()
        if self.symbols:
            self.symbols.free()

    @always_inline("nodebug")
    fn __len__(self) -> Int:
        """
        Returns the number of elements in the Collection.
        """
        return self.size

    @always_inline("nodebug")
    fn _realloc(inout self, new_capacity: Int):
        """
        Reallocates the Collection to the new capacity.
        """
        var new_data = AnyPointer[Tensor[dtype]].alloc(new_capacity)
        var new_symbols = DTypePointer[DType.uint32].alloc(new_capacity)

        for i in range(self.size):
            (new_data + i).emplace_value((self.data + i).take_value())
            new_symbols[i] = self.symbols[i]

        self.data.free()
        self.symbols.free()

        self.data = new_data
        self.symbols = new_symbols
        self.capacity = new_capacity

    @always_inline("nodebug")
    fn append(inout self, owned value: Tensor[dtype], symbol: Symbol):
        """
        Appends a tensor and its associated symbol to the Collection.
        """
        self.append(value ^, symbol.name)

    @always_inline("nodebug")
    fn append(inout self, owned value: Tensor[dtype], symbol_name: UInt32):
        """
        Appends a tensor and its associated symbol name to the Collection.
        """
        if self.size >= self.capacity:
            self._realloc(max(1, self.capacity * 2))
        (self.data + self.size).emplace_value(value ^)
        self.symbols[self.size] = symbol_name
        self.size += 1

    @always_inline("nodebug")
    fn get_index(self, symbol_name: UInt32) -> Int:
        """
        Returns the index of the tensor with the given symbol name.
        """
        for i in range(self.size):
            if self.symbols[i] == symbol_name:
                return i
        return -1

    @always_inline("nodebug")
    fn __refitem__[
        mutability: __mlir_type.i1,
        lifetime: AnyLifetime[mutability].type,
    ](
        self: Reference[Self, mutability, lifetime].mlir_ref_type,
        symbol: Symbol,
    ) -> Reference[Tensor[dtype], mutability, lifetime]:
        """
        Returns a reference to the tensor with the given symbol.
        """
        var index = Reference(self)[].get_index(symbol.name)

        return Reference(
            __mlir_op.`lit.ref.from_pointer`[
                _type = Reference[Tensor[dtype], mutability, lifetime].mlir_ref_type
            ]((Reference(self)[].data + index).value)
        )

    @always_inline("nodebug")
    fn clear(inout self):
        """
        Clears the Collection, removing all tensors and symbols.
        """
        for i in range(self.size):
            _ = (self.data + i).take_value()
        memset_zero(self.symbols, self.capacity)
        self.size = 0

    @always_inline("nodebug")
    fn set_zero(self):
        """
        Zeroes out all the tensors in the collection.
        """
        for i in range(self.size):
            self.data[i].zero()
