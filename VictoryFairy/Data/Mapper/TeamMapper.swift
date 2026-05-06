import Foundation

enum TeamMapper {
    static func map(_ dto: TeamDTO) -> KBOTeam {
        KBOTeam(
            id: dto.id,
            name: dto.name,
            shortName: dto.shortName,
            city: dto.city,
            homeStadiumName: dto.homeStadiumName,
            primaryColorHex: dto.primaryColorHex,
            secondaryColorHex: dto.secondaryColorHex,
            accentColorHex: dto.accentColorHex,
            textOnPrimaryHex: dto.textOnPrimaryHex,
            active: dto.active
        )
    }
}
