function generate_test_data(filename, num_bits)
    % 定义参数
    trellis = poly2trellis(3, [7 5]);

    % 生成随机比特
    bits = randi([0 1], num_bits, 1);

    % 卷积编码
    encoded_bits = convenc(bits, trellis);

    % BPSK调制
    symbols = 2 * encoded_bits - 1;

    % 添加AWGN噪声
    noisy_symbols = awgn(symbols, 10); % 10 dB SNR

    % 模拟软符号（作为复数）
    soft_symbols = noisy_symbols + 1i * zeros(size(noisy_symbols));

    % 保存为int8 I/Q对
    fid = fopen(filename, 'w');
    if fid == -1
        error('Cannot open file for writing: %s', filename);
    end

    % 将复数转换为I/Q int8并写入文件
    iq_data = [real(soft_symbols)'; imag(soft_symbols)'];
    iq_data = int8(iq_data(:) * 127); % 缩放到int8范围

    fwrite(fid, iq_data, 'int8');
    fclose(fid);
end
