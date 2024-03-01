from tensor import Tensor, TensorShape
from math import sub, mul, exp, max, pow, div

from dainemo import GRAPH
from dainemo.autograd.node import Node
from dainemo.utils.tensorutils import (
    elwise_op,
    elwise_transform,
    fill,
    tsum,
    tmax,
)


# --------------UNARY OPERATORS----------------


# <------------SIGMOID------------>
struct SIGMOID:
    @staticmethod
    fn sigmoid[
        type: DType, simd_width: Int
    ](x: SIMD[type, simd_width]) -> SIMD[type, simd_width]:
        return 1 / (1 + exp(-x))

    @staticmethod
    fn forward(n: Node[dtype]) -> Node[dtype]:
        """Forward operation of sigmoid."""
        var res: Tensor[dtype] = elwise_transform[dtype, nelts, SIGMOID.sigmoid](
            n.tensor
        )
        return GRAPH.create_graph_node[Self.backward](res, n)

    @staticmethod
    fn backward(
        ug: Tensor[dtype], tensor_vec: DynamicVector[String], tensor_id: Int
    ) -> Tensor[dtype]:
        """Backward operation of sigmoid."""
        # d(sigmod(x))/dx = sigmoid(x) * (1 - sigmoid(x))
        var t = GRAPH.graph[GRAPH.get_node_idx(tensor_vec[0])].tensor
        # sigmoid(x)
        var sigmoid_res = elwise_transform[dtype, nelts, SIGMOID.sigmoid](t)
        # 1 - sigmoid(x)
        var sub_res = elwise_op[dtype, nelts, sub](SIMD[dtype, 1](1), sigmoid_res)
        # sigmoid(x) * (1 - sigmoid(x))
        var res = elwise_op[dtype, nelts, mul](sigmoid_res, sub_res)

        return elwise_op[dtype, nelts, mul](ug, res)


# <------------RELU------------>
struct RELU:
    @staticmethod
    fn forward(n: Node[dtype]) -> Node[dtype]:
        """Forward operation of relu."""
        var res: Tensor[dtype] = elwise_op[dtype, nelts, max](
            n.tensor, SIMD[dtype, 1](0)
        )
        return GRAPH.create_graph_node[Self.backward](res, n)

    @staticmethod
    fn relu_derivative[
        type: DType, simd_width: Int
    ](x: SIMD[type, simd_width]) -> SIMD[type, simd_width]:
        return 1 if x > 0 else 0

    @staticmethod
    fn backward(
        ug: Tensor[dtype], tensor_vec: DynamicVector[String], tensor_id: Int
    ) -> Tensor[dtype]:
        """Backward operation of relu."""
        # d(relu(x))/dx = 1 if x > 0 else 0. We also give 0 to x = 0 instead of undefined.
        var t = GRAPH.graph[GRAPH.get_node_idx(tensor_vec[0])].tensor
        var res = elwise_transform[dtype, nelts, RELU.relu_derivative](t)

        return elwise_op[dtype, nelts, mul](ug, res)


# <------------TANH------------>
struct TANH:
    @staticmethod
    fn tanh[
        type: DType, simd_width: Int
    ](x: SIMD[type, simd_width]) -> SIMD[type, simd_width]:
        return (exp(x) - exp(-x)) / (exp(x) + exp(-x))

    @staticmethod
    fn forward(n: Node[dtype]) -> Node[dtype]:
        """Forward operation of tanh."""
        var res: Tensor[dtype] = elwise_transform[dtype, nelts, TANH.tanh](n.tensor)
        return GRAPH.create_graph_node[Self.backward](res, n)

    @staticmethod
    fn backward(
        ug: Tensor[dtype], tensor_vec: DynamicVector[String], tensor_id: Int
    ) -> Tensor[dtype]:
        """Backward operation of tanh."""
        # d(tanh(x))/dx = 1 - tanh(x) ** 2
        var t = GRAPH.graph[GRAPH.get_node_idx(tensor_vec[0])].tensor
        var tanh_res = elwise_transform[dtype, nelts, TANH.tanh](t)
        var tanh_res_square = elwise_op[dtype, nelts, mul](tanh_res, tanh_res)
        var res = elwise_op[dtype, nelts, sub](SIMD[dtype, 1](1), tanh_res_square)

        return elwise_op[dtype, nelts, mul](ug, res)

# <------------SOFTMAX------------>
struct SOFTMAX:
    @staticmethod
    fn softmax[axis: Int](n: Tensor[dtype]) -> Tensor[dtype]:
        """Softmax operation."""
        # exp(x_i - max(x_j)) / sum(exp(x_j))
        var max_val = tmax[dtype, nelts](n, axis)
        var x_minus_max = elwise_op[dtype, nelts, sub](n, max_val)

        var exp_res = elwise_transform[dtype, nelts, exp](x_minus_max)
        var sum_res = tsum[dtype, nelts](exp_res, axis)
        var res = elwise_op[dtype, nelts, div](exp_res, sum_res)

        return res

    @staticmethod
    fn forward[axis: Int](n: Node[dtype]) -> Node[dtype]:
        """Forward operation of softmax."""
        # softmax: exp(x_i) / sum(exp(x_j))
        # stable softmax: exp(x_i - max(x_j)) / sum(exp(x_j))
        var softmax_res = Self.softmax[axis](n.tensor)
        var res = elwise_op[dtype, nelts, div](n.tensor, softmax_res)

        return GRAPH.create_graph_node[Self.backward[axis]](res, n)

    @staticmethod
    fn backward[axis: Int](
        ug: Tensor[dtype], tensor_vec: DynamicVector[String], tensor_id: Int
    ) -> Tensor[dtype]:
        """Backward operation of softmax."""
        pass