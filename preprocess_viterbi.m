% 主函数
function preprocess_viterbi(input_filename, output_filename)
    % 如果没有提供参数，则运行一个测试用例
    if nargin == 0
        input_filename = 'test_data.s';
        output_filename = 'decoded_bits.txt';
        fprintf('Running test case with generated data...\n');
        generate_test_data(input_filename, 1024);
    end

    % 定义参数
    phases = [0, 90, 180, 270];
    iq_swaps = [0, 1]; % 0 for normal, 1 for swapped
    ber_threshold = 0.300;

    % 定义卷积码的网格（trellis），这里使用一个常见的例子
    % k=3, n=2, G=[1 1 1; 1 0 1]
    trellis = poly2trellis(3, [7 5]); % 八进制表示

    % 读取软符号数据
    soft_symbols = read_soft_symbols(input_filename);

    % 初始化最佳参数和BER结果
    best_params = struct('phase', 0, 'iq_swap', 0, 'ber', inf);
    ber_results = zeros(length(phases), length(iq_swaps));

    % 同步搜索
    sync_symbols = soft_symbols(1:min(end, 2048)); % 使用一部分数据进行同步

    for i = 1:length(phases)
        phase = phases(i);
        for j = 1:length(iq_swaps)
            iq_swap = iq_swaps(j);

            % 旋转和交换IQ
            processed_symbols = rotate_soft(sync_symbols, phase);
            if iq_swap
                processed_symbols = imag(processed_symbols) + 1i * real(processed_symbols);
            end

            % 解码和重编码以计算BER
            decoded_bits = viterbi_decode(processed_symbols, trellis);
            re_encoded_bits = convolutional_encode(decoded_bits, trellis);

            % 将重编码的比特转换为软符号（BPSK）
            re_encoded_symbols = 2 * re_encoded_bits - 1;

            % 计算BER
            ber = 1 - mean(real(processed_symbols) .* re_encoded_symbols(1:length(processed_symbols))); % 这是一个简化的BER估计

            ber_results(i, j) = ber;

            % 更新最佳参数
            if ber < best_params.ber
                best_params.ber = ber;
                best_params.phase = phase;
                best_params.iq_swap = iq_swap;
            end
        end
    end

    % 如果没有找到低于阈值的BER，则选择最佳的
    if best_params.ber > ber_threshold
        fprintf('Warning: BER is above threshold. Using best found parameters.\n');
    end

    fprintf('Best parameters found: Phase %d°, IQ Swap %d, BER %.4f\n', ...
        best_params.phase, best_params.iq_swap, best_params.ber);

    % 使用最佳参数进行解码
    processed_symbols = rotate_soft(soft_symbols, best_params.phase);
    if best_params.iq_swap
        processed_symbols = imag(processed_symbols) + 1i * real(processed_symbols);
    end
    hard_bits = viterbi_decode(processed_symbols, trellis);

    % 保存硬比特
    save_hard_bits(output_filename, hard_bits);

    % 可视化
    plot_ber_results(ber_results);
end

% 读取.s文件
function soft_symbols = read_soft_symbols(filename)
    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open file: %s', filename);
    end
    % 读取int8数据并将其转换为复数
    data = fread(fid, 'int8=>double');
    fclose(fid);

    % 检查数据是否为偶数长度
    if mod(length(data), 2) ~= 0
        error('The number of data points must be even (I/Q pairs).');
    end

    % 将I和Q数据合并为复数
    soft_symbols = data(1:2:end) + 1i * data(2:2:end);
end

% 旋转软符号
function rotated_symbols = rotate_soft(symbols, phase)
    % 将相位从度转换为弧度
    rad = deg2rad(phase);
    % 应用旋转
    rotated_symbols = symbols * exp(1i * rad);
end

% Viterbi解码器
function decoded_bits = viterbi_decode(symbols, trellis)
    % vitdec需要量化的输入，所以我们将复数软符号转换为量化的整数
    % 这里我们只使用实部，因为Viterbi解码器处理的是比特流
    quantized_symbols = quantiz(real(symbols), [-0.5 0.5]); % 简单的量化
    decoded_bits = vitdec(quantized_symbols, trellis, 30, 'term', 'hard'); % 30是回溯深度
end

% 卷积编码器
function encoded_bits = convolutional_encode(bits, trellis)
    encoded_bits = convenc(bits, trellis);
end

% 计算BER
function ber = calculate_ber(bits1, bits2)
    % 确保两个输入向量的长度相同
    len = min(length(bits1), length(bits2));
    bits1 = bits1(1:len);
    bits2 = bits2(1:len);

    % 计算误码数
    error_count = sum(bits1 ~= bits2);

    % 计算BER
    ber = error_count / len;
end

% 保存硬比特到文件
function save_hard_bits(filename, bits)
    fid = fopen(filename, 'w');
    if fid == -1
        error('Cannot open file for writing: %s', filename);
    end
    fprintf(fid, '%d', bits);
    fclose(fid);
end

% 绘制BER结果
function plot_ber_results(ber_results)
    figure;
    bar(ber_results');
    xlabel('Phase (°)')
    ylabel('Bit Error Rate (BER)')
    title('BER for different Phase and IQ configurations')
    legend('IQ Normal', 'IQ Swapped')
    set(gca, 'xticklabel', {'0', '90', '180', '270'})
end
