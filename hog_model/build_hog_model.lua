require 'torch'
require 'nn'

local N = {}

--build a convnet model
local function conv_net(convlayer_params, w_scale)

  local num_filters = convlayer_params['num_filters'] --{64,  64,  128,  128,  256, 256, 512, 512, 1024}
  local filter_sizes =  convlayer_params['filter_size'] --{5,   3,   3,   3,   3,   3,   3,   3,   3}
  local filter_strides = convlayer_params['stride'] --{2,   1,   2,   1,   2,   1,   2,   1,   2}
  local use_sbatchnorm = convlayer_params['s_batch_norm']
  local use_maxpool = convlayer_params['max_pooling']
  local maxpool_dim = convlayer_params['pool_dims']
  local maxpool_stride = convlayer_params['pool_strides']
  local use_conv_dropout = convlayer_params['dropout']

  -- C: number of channels , H,W: height and width of an image

  --[[ I just made a long enough dropout option that can be used for a conv network with
       maximum number of conv layers of 9 ]]--
  local conv_dropout = {0.1, 0.1, 0.2, 0.2, 0.3, 0.3, 0.4, 0.4, 0.5}

  local C, H, W = 1, 48, 48

  local next_C = C
  local next_H = H
  local next_W = W

  -- add layers
  local layer_counter = 0

  local conv_model = nn.Sequential()
  local m = conv_model.modules
  local layer_counter = 0
  for i = 1, #num_filters do

    local zero_pad = (filter_sizes[i] - 1) / 2

    conv_model:add(nn.SpatialConvolution(next_C, num_filters[i], filter_sizes[i], filter_sizes[i],
                filter_strides[i], filter_strides[i], zero_pad, zero_pad))

    -- Manually initialize bias and weights
    layer_counter = layer_counter + 1
    m[layer_counter].bias:fill(0)
    --m[layer_counter].weight:randn(num_filters[i], next_C, filter_sizes[i], filter_sizes[i])
    --m[layer_counter].weight:div(w_scale)

    -- data size after conv layer operation   
    next_C = num_filters[i]
    next_W = (next_W + 2*zero_pad - filter_sizes[i]) / filter_strides[i] + 1
    next_H = (next_H + 2*zero_pad - filter_sizes[i]) / filter_strides[i] + 1

    if use_sbatchnorm then
        conv_model:add(nn.SpatialBatchNormalization(next_C))
        layer_counter = layer_counter + 1
        --m[layer_counter].weight:fill(1.0)
        --m[layer_counter].bias:fill(0.0)
    end

    conv_model:add(nn.ReLU())
    layer_counter = layer_counter + 1

    if use_conv_dropout then
        conv_model:add(nn.Dropout(conv_dropout[i]))
        layer_counter = layer_counter + 1
    end

    if use_maxpool[i] then
        conv_model:add(nn.SpatialMaxPooling(maxpool_dim, maxpool_dim, maxpool_stride, maxpool_stride))
        layer_counter = layer_counter + 1

         -- data size after max pooling operation
        next_W = (next_W - maxpool_dim) / maxpool_stride + 1
        next_H = (next_H - maxpool_dim) / maxpool_stride + 1
    end

  end

  local next_D = next_C * next_W * next_H
  conv_model:add(nn.View(-1):setNumInputDims(3))

  return conv_model, next_D

end

local function fc_net(affinelayer_params, fan_in, w_scale)

  local hidden_dims = affinelayer_params['hidden_dims']
  local use_batchnorm = affinelayer_params['batch_norm']
  local use_dropout = affinelayer_params['dropout']

  local num_classes = 7
  local next_D = fan_in
  local fc_model = nn.Sequential()
  local m = fc_model.modules
  local layer_counter = 0
  for i = 1, #hidden_dims do

    fc_model:add(nn.Linear(next_D, hidden_dims[i]))
    layer_counter = layer_counter + 1
    m[layer_counter].bias:fill(0)
    --m[layer_counter].weight:randn(next_D, hidden_dims[i]) 
    --m[layer_counter].weight:div(w_scale)
    next_D = hidden_dims[i]

    if use_batchnorm then
      fc_model:add(nn.BatchNormalization(hidden_dims[i]))
      layer_counter = layer_counter + 1
      --m[layer_counter].weight:fill(1.0)
      --m[layer_counter].bias:fill(0.0)
    end

    if use_dropout then
      fc_model:add(nn.Dropout(0.7))
      layer_counter = layer_counter + 1
    end

    fc_model:add(nn.ReLU())
    layer_counter = layer_counter + 1

  end

  fc_model:add(nn.Linear(next_D, num_classes))
  layer_counter = layer_counter + 1
  m[layer_counter].bias:fill(0)
  --m[layer_counter].weight:randn(next_D, num_classes)
  --m[layer_counter].weight:div(w_scale)

  return fc_model

end

N = { conv_net = conv_net,
      fc_net = fc_net
    }

return N
