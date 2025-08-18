/// # Animal Passport - Sistema de Certificación Digital para Animales Rescatados
/// 
/// Este módulo implementa un sistema de pasaportes digitales (NFTs) para animales rescatados,
/// permitiendo crear, transferir y gestionar certificaciones únicas e inmutables.
/// 
/// ## Funcionalidades principales:
/// - Emisión de pasaportes digitales únicos para cada animal
/// - Transferencia segura de propiedad entre usuarios
/// - Verificación de autenticidad y validez
/// - Actualización de información por el emisor original
/// - Sistema de eventos para tracking
/// 
/// ## Uso:
/// 1. `create_passport()` - Crea un nuevo pasaporte para un animal rescatado
/// 2. `transfer_passport()` - Transfiere la propiedad del pasaporte
/// 3. `update_animal_info()` - Actualiza el nombre del animal (solo emisor original)
/// 4. `verify_passport()` - Verifica la validez del pasaporte
/// 5. Funciones getter para acceder a la información del pasaporte

module animal_passport::passport {
    use sui::object::UID;
    use sui::tx_context::TxContext;
    use std::string::String;

    /// Código de error para permisos insuficientes
    const EInsufficientPermissions: u64 = 1;
    /// Código de error para pasaporte inválido
    const EInvalidPassport: u64 = 2;

    /// Estructura principal del NFT Pasaporte
    /// Representa un certificado digital único para un animal rescatado
    public struct Passport has key, store {
        id: UID,
        animal_name: String,      // Nombre del animal
        animal_type: String,      // Tipo/especie del animal
        rescue_date: u64,         // Fecha de rescate (timestamp)
        issued_by: address,       // Dirección del emisor del certificado
    }

    /// Evento emitido cuando se crea un nuevo pasaporte
    public struct PassportCreated has copy, drop {
        passport_id: address,
        animal_name: String,
        animal_type: String,
        issued_by: address,
        rescue_date: u64,
    }

    /// Evento emitido cuando se transfiere un pasaporte
    public struct PassportTransferred has copy, drop {
        passport_id: address,
        from: address,
        to: address,
    }

    /// Evento emitido cuando se actualiza información del animal
    public struct AnimalInfoUpdated has copy, drop {
        passport_id: address,
        old_name: String,
        new_name: String,
        updated_by: address,
    }

    /// **Función 1: Emisión de pasaportes**
    /// Crea un nuevo pasaporte digital para un animal rescatado
    /// Retorna el objeto Passport para uso posterior
    public fun issue_passport(
        animal_name: vector<u8>,
        animal_type: vector<u8>,
        rescue_date: u64,
        ctx: &mut TxContext
    ): Passport {
        let passport = Passport {
            id: sui::object::new(ctx),
            animal_name: std::string::utf8(animal_name),
            animal_type: std::string::utf8(animal_type),
            rescue_date,
            issued_by: sui::tx_context::sender(ctx),
        };

        // Emitir evento de creación
        sui::event::emit(PassportCreated {
            passport_id: sui::object::uid_to_address(&passport.id),
            animal_name: passport.animal_name,
            animal_type: passport.animal_type,
            issued_by: passport.issued_by,
            rescue_date: passport.rescue_date,
        });

        passport
    }

    /// **Función 2: Creación y transferencia directa**
    /// Función entry para crear un pasaporte y transferirlo al emisor
    /// Esta es la función principal para usuarios finales
    entry fun create_passport(
        animal_name: vector<u8>,
        animal_type: vector<u8>,
        rescue_date: u64,
        ctx: &mut TxContext
    ) {
        let passport = issue_passport(animal_name, animal_type, rescue_date, ctx);
        let sender = sui::tx_context::sender(ctx);
        sui::transfer::transfer(passport, sender);
    }

    /// **Función 3: Transferencia de pasaportes**
    /// Permite transferir un pasaporte a otro usuario
    /// Emite evento de transferencia para tracking
    public fun transfer_passport(
        passport: Passport,
        recipient: address,
        ctx: &TxContext
    ) {
        // Emitir evento de transferencia
        sui::event::emit(PassportTransferred {
            passport_id: sui::object::uid_to_address(&passport.id),
            from: sui::tx_context::sender(ctx),
            to: recipient,
        });

        sui::transfer::transfer(passport, recipient);
    }

    /// **Función 4: Actualización de información**
    /// Permite al emisor original actualizar el nombre del animal
    /// Solo el emisor original tiene permisos para esta operación
    public fun update_animal_info(
        passport: &mut Passport,
        new_name: vector<u8>,
        ctx: &TxContext
    ) {
        // Verificar que solo el emisor original puede actualizar
        assert!(passport.issued_by == sui::tx_context::sender(ctx), EInsufficientPermissions);
        
        let old_name = passport.animal_name;
        passport.animal_name = std::string::utf8(new_name);

        // Emitir evento de actualización
        sui::event::emit(AnimalInfoUpdated {
            passport_id: sui::object::uid_to_address(&passport.id),
            old_name,
            new_name: passport.animal_name,
            updated_by: sui::tx_context::sender(ctx),
        });
    }

    /// **Función 5: Verificación de pasaportes**
    /// Verifica si un pasaporte es válido verificando que tenga información completa
    /// Retorna true si el pasaporte contiene datos válidos
    public fun verify_passport(passport: &Passport): bool {
        !std::string::is_empty(&passport.animal_name) && 
        !std::string::is_empty(&passport.animal_type) &&
        passport.rescue_date > 0
    }

    // === FUNCIONES GETTER ===
    
    /// Obtiene el nombre del animal
    public fun get_animal_name(passport: &Passport): &String {
        &passport.animal_name
    }

    /// Obtiene el tipo/especie del animal
    public fun get_animal_type(passport: &Passport): &String {
        &passport.animal_type
    }

    /// Obtiene la fecha de rescate
    public fun get_rescue_date(passport: &Passport): u64 {
        passport.rescue_date
    }

    /// Obtiene la dirección del emisor
    public fun get_issued_by(passport: &Passport): address {
        passport.issued_by
    }

    /// Obtiene el ID único del pasaporte
    public fun get_id(passport: &Passport): &UID {
        &passport.id
    }

    /// Obtiene información completa del pasaporte
    public fun get_passport_info(passport: &Passport): (String, String, u64, address) {
        (passport.animal_name, passport.animal_type, passport.rescue_date, passport.issued_by)
    }

    // === TESTS ===

    #[test_only]
    use sui::test_scenario;

    #[test]
    /// Test completo del ciclo de vida de un pasaporte
    fun test_passport_lifecycle() {
        let admin = @0xABCD;
        let user = @0x1234;
        let mut scenario_val = sui::test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        // 1. Crear un pasaporte
        {
            let ctx = sui::test_scenario::ctx(scenario);
            create_passport(
                b"Firulais",
                b"Perro",
                1640995200,
                ctx
            );
        };

        // 2. Verificar creación
        sui::test_scenario::next_tx(scenario, admin);
        {
            assert!(sui::test_scenario::has_most_recent_for_address<Passport>(admin), 0);
            let passport = sui::test_scenario::take_from_address<Passport>(scenario, admin);
            
            // Verificar datos
            assert!(get_animal_name(&passport) == &std::string::utf8(b"Firulais"), 1);
            assert!(get_animal_type(&passport) == &std::string::utf8(b"Perro"), 2);
            assert!(verify_passport(&passport), 3);
            
            sui::test_scenario::return_to_address(admin, passport);
        };

        // 3. Transferir pasaporte
        sui::test_scenario::next_tx(scenario, admin);
        {
            let passport = sui::test_scenario::take_from_address<Passport>(scenario, admin);
            let ctx = sui::test_scenario::ctx(scenario);
            transfer_passport(passport, user, ctx);
        };

        // 4. Verificar transferencia
        sui::test_scenario::next_tx(scenario, user);
        {
            assert!(sui::test_scenario::has_most_recent_for_address<Passport>(user), 4);
        };

        sui::test_scenario::end(scenario_val);
    }

    #[test]
    /// Test de actualización de información
    fun test_update_animal_info() {
        let admin = @0xABCD;
        let mut scenario_val = sui::test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        // Crear pasaporte
        {
            let ctx = sui::test_scenario::ctx(scenario);
            create_passport(b"Michi", b"Gato", 1640995200, ctx);
        };

        // Actualizar información
        sui::test_scenario::next_tx(scenario, admin);
        {
            let mut passport = sui::test_scenario::take_from_address<Passport>(scenario, admin);
            let ctx = sui::test_scenario::ctx(scenario);
            
            update_animal_info(&mut passport, b"Michi Updated", ctx);
            assert!(get_animal_name(&passport) == &std::string::utf8(b"Michi Updated"), 0);
            
            sui::test_scenario::return_to_address(admin, passport);
        };

        sui::test_scenario::end(scenario_val);
    }
}
