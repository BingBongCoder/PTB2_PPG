clear;
clc;

% 1. KONFIGURASI SERIAL & PARAMETER AWAL

pilihanN = 1;
COMPORT = 'COM4'; 
BAUD_RATE = 115200;
BPM_TARGET_MIN = 40.0; 
BPM_TARGET_MAX = 200.0; 
TIMEOUT_S = 100000;

try
    s = serialport(COMPORT, BAUD_RATE); 
    s.Timeout = TIMEOUT_S;
    
    disp(['Terkoneksi ke ', COMPORT, ' dengan baud rate ', num2str(BAUD_RATE)]);
    
    flush(s);
catch ME
    disp(['ERROR: Tidak dapat membuka port serial ', COMPORT]);
    disp(['Pesan: ', ME.message]);
    return;
end

% 2. PARAMETER DFT
Fs = 20; 
if (pilihanN == 1)
    N = 128;    
    BPM_min_index = 4;  
    BPM_max_index = 21; 
elseif (pilihanN == 2)
    N = 256;    
    BPM_min_index = 9;  
    BPM_max_index = 43;
elseif (pilihanN == 3)
    N = 512;    
    BPM_min_index = 17;  
    BPM_max_index = 85;
elseif (pilihanN == 4)
    N = 1024;    
    BPM_min_index = 35;  
    BPM_max_index = 170; 
end
        
resolusi_Fs = Fs / N;
Max_Freq_Search = BPM_max_index * resolusi_Fs;
k_index_search = BPM_min_index : BPM_max_index;
frequency_hz_search = k_index_search * resolusi_Fs;
BPM_axis_search = frequency_hz_search * 60;
FULL_SPECTRUM_SIZE = N/2; 
full_k_index = 1 : FULL_SPECTRUM_SIZE; 
full_frequency_hz = full_k_index * resolusi_Fs;

% 3. INISIALISASI PLOT GRAFIK
figure(1);
% Plot 1: Magnitudo vs Frekuensi
h_stem1 = stem(full_frequency_hz, zeros(1, FULL_SPECTRUM_SIZE), 'b', 'LineWidth', 1.5); 
grid on;
title('Spektrum Magnitudo PPG (Hz)');
xlabel('Frekuensi (Hz)');
ylabel('Magnitudo (Unit ADC Skala DFT)');
xlim([0, Max_Freq_Search]); 
ylim manual; 

figure(2);
% Plot 2: Magnitudo vs BPM 
h_stem2 = stem(BPM_axis_search, zeros(size(BPM_axis_search)), 'r', 'LineWidth', 1.5); 
grid on;
title('Spektrum Magnitudo PPG (BPM)');
xlabel('Detak Jantung (BPM)');
ylabel('Magnitudo (Unit ADC Skala DFT)');
xlim([BPM_TARGET_MIN BPM_TARGET_MAX]);
ylim manual;

disp('Memulai mode mendengarkan berkelanjutan. Tekan Ctrl+C untuk berhenti.');

while true
    
    disp('----------------------------------------------------');
    disp('Menunggu Header...');
    
    try
        current_line = '';
        while ~contains(current_line, "SPECTRUM ANALYSIS START")
            current_line = readline(s);
        end

        disp('Header diterima. Membaca 2 baris data berikutnya...');
        
        data_string_only = readline(s); 
        
        footer_line = readline(s);
        
        if contains(footer_line, "SPECTRUM ANALYSIS END")
            
            disp('Data lengkap diterima.');
            
            magnitudes = sscanf(data_string_only, '%f,');
            magnitudes = magnitudes'; 
            
            if isempty(magnitudes) || length(magnitudes) ~= length(BPM_axis_search)
                disp('PERINGATAN: Jumlah data tidak sesuai N. Mengulang siklus.');
                continue;
            end
            
            full_magnitudes = zeros(1, FULL_SPECTRUM_SIZE);
            start_index_array = BPM_min_index + 1; 
            end_index_array = BPM_max_index + 1;
            
            full_magnitudes(start_index_array : end_index_array) = magnitudes;
            
            max_mag_val = max(magnitudes); % Nilai Magnitudo Maksimal
            
            % 4. PLOTTING DAN ANALISIS
            
            % Update PLOT 1: Magnitudo vs. Frekuensi (Hz)
            figure(1);
            h_stem1.XData = full_frequency_hz; 
            h_stem1.YData = full_magnitudes;  
            ylim([0 max_mag_val*1.1]); 
            
            % Update PLOT 2: Magnitudo vs. BPM
            figure(2);
            h_stem2.XData = BPM_axis_search;
            h_stem2.YData = magnitudes;
            ylim([0 max_mag_val*1.1]); 
            
            % Analisis BPM
            [max_mag, max_idx_in_array] = max(magnitudes); 
            k_peak_index = k_index_search(max_idx_in_array);      
            BPM_result = BPM_axis_search(max_idx_in_array);       
            
            disp(['Puncak Magnitudo Terdeteksi: ', num2str(max_mag)]);
            disp(['Hasil BPM: ', num2str(BPM_result, 2), ' BPM']);
            
            drawnow; 
            
        else
            disp('PERINGATAN: Footer hilang. Siklus DFT rusak. Mencari paket baru...');
            flush(s); 
        end
    end
end 
% Kode di bawah ini hanya dijalankan jika pengguna alat menekan ctrl+c
disp('Skrip dihentikan. Melepaskan port serial.');
clear s;